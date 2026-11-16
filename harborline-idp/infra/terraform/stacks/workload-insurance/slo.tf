# SLOs as code (docs/operations/slos.md). Multi-window, multi-burn-rate alerts (Google SRE workbook, ch. 5).
# Metrics come from OpenTelemetry HTTP server instrumentation exported by the collector's Prometheus exporter.

locals {
  slo_services = {
    # Budgets are strings so the PromQL stays exact (no float rendering artefacts).
    policy-api = { availability_budget = "0.001", latency_threshold_s = "0.5", latency_budget = "0.01" }
  }
  windows = ["5m", "30m", "1h", "6h"]

  recording_rules = merge([
    for svc, _ in local.slo_services : merge(
      {
        for w in local.windows : "slo:sli_error:ratio_rate${w}:${svc}" => {
          record = "slo:sli_error:ratio_rate${w}"
          expr   = "sum(rate(http_server_request_duration_seconds_count{service_name=\"${svc}\",http_response_status_code=~\"5..\"}[${w}])) / clamp_min(sum(rate(http_server_request_duration_seconds_count{service_name=\"${svc}\"}[${w}])), 1e-9)"
          svc    = svc
        }
      },
      {
        for w in local.windows : "slo:sli_latency_violation:ratio_rate${w}:${svc}" => {
          record = "slo:sli_latency_violation:ratio_rate${w}"
          expr   = "1 - (sum(rate(http_server_request_duration_seconds_bucket{service_name=\"${svc}\",le=\"${local.slo_services[svc].latency_threshold_s}\"}[${w}])) / clamp_min(sum(rate(http_server_request_duration_seconds_count{service_name=\"${svc}\"}[${w}])), 1e-9))"
          svc    = svc
        }
      },
    )
  ]...)

  burn_alerts = merge([
    for svc, s in local.slo_services : {
      "${svc}-availability-fast-burn" = {
        expr     = "slo:sli_error:ratio_rate1h{service_name=\"${svc}\"} > (14.4 * ${s.availability_budget}) and slo:sli_error:ratio_rate5m{service_name=\"${svc}\"} > (14.4 * ${s.availability_budget})"
        severity = 1
        summary  = "${svc}: availability error budget burning 14.4x (2% of 30-day budget in 1h)."
        runbook  = "high-error-rate"
      }
      "${svc}-availability-slow-burn" = {
        expr     = "slo:sli_error:ratio_rate6h{service_name=\"${svc}\"} > (6 * ${s.availability_budget}) and slo:sli_error:ratio_rate30m{service_name=\"${svc}\"} > (6 * ${s.availability_budget})"
        severity = 2
        summary  = "${svc}: availability error budget burning 6x (5% of 30-day budget in 6h)."
        runbook  = "high-error-rate"
      }
      "${svc}-latency-fast-burn" = {
        expr     = "slo:sli_latency_violation:ratio_rate1h{service_name=\"${svc}\"} > (14.4 * ${s.latency_budget}) and slo:sli_latency_violation:ratio_rate5m{service_name=\"${svc}\"} > (14.4 * ${s.latency_budget})"
        severity = 2
        summary  = "${svc}: latency SLO (p99 < ${s.latency_threshold_s}s) budget burning 14.4x."
        runbook  = "high-latency"
      }
    }
  ]...)
}

resource "azurerm_monitor_alert_prometheus_rule_group" "slo_recording" {
  name                = "prg-ins-${var.environment}-slo-recording"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  cluster_name        = data.azurerm_kubernetes_cluster.this.name
  scopes              = [data.azurerm_monitor_workspace.central.id]
  rule_group_enabled  = true
  interval            = "PT1M"
  tags                = module.naming.tags

  dynamic "rule" {
    for_each = local.recording_rules
    content {
      enabled    = true
      record     = rule.value.record
      expression = rule.value.expr
      labels     = { service_name = rule.value.svc }
    }
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "slo_alerts" {
  name                = "prg-ins-${var.environment}-slo-alerts"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  cluster_name        = data.azurerm_kubernetes_cluster.this.name
  scopes              = [data.azurerm_monitor_workspace.central.id]
  rule_group_enabled  = var.environment != "dev"
  interval            = "PT1M"
  tags                = module.naming.tags

  dynamic "rule" {
    for_each = local.burn_alerts
    content {
      alert       = replace(title(replace(rule.key, "-", " ")), " ", "")
      enabled     = true
      expression  = rule.value.expr
      for         = "PT2M"
      severity    = rule.value.severity
      labels      = { team = "insurance-digital", environment = var.environment }
      annotations = {
        summary     = rule.value.summary
        runbook_url = "https://backstage.harborline.example/docs/default/component/harborline-idp/operations/runbooks/${rule.value.runbook}/"
      }

      action {
        action_group_id = data.azurerm_monitor_action_group.platform.id
      }

      alert_resolution {
        auto_resolved   = true
        time_to_resolve = "PT15M"
      }
    }
  }
}
