# Platform-level Prometheus alert rules. Every alert links to a runbook (docs/operations/runbooks).
# Application SLO burn-rate alerts are defined per workload stack.

locals {
  runbook_base    = "https://backstage.harborline.example/docs/default/component/harborline-idp/operations/runbooks"
  platform_alerts = {
    KubeNodeNotReady = {
      expr     = "kube_node_status_condition{condition=\"Ready\",status=\"true\"} == 0"
      for      = "PT10M"
      severity = 2
      summary  = "Node {{ $labels.node }} has been NotReady for 10 minutes."
      runbook  = "aks-node-not-ready"
    }
    KubePodCrashLooping = {
      expr     = "max_over_time(kube_pod_container_status_waiting_reason{reason=\"CrashLoopBackOff\"}[5m]) >= 1"
      for      = "PT15M"
      severity = 3
      summary  = "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping."
      runbook  = "high-error-rate"
    }
    KubeDeploymentReplicasMismatch = {
      expr     = "kube_deployment_spec_replicas != kube_deployment_status_replicas_available"
      for      = "PT15M"
      severity = 3
      summary  = "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has unavailable replicas."
      runbook  = "high-error-rate"
    }
    KubeContainerOOMKilled = {
      expr     = "increase(kube_pod_container_status_restarts_total[10m]) > 0 and on(namespace,pod,container) kube_pod_container_status_last_terminated_reason{reason=\"OOMKilled\"} == 1"
      for      = "PT0M"
      severity = 3
      summary  = "Container {{ $labels.container }} in {{ $labels.namespace }}/{{ $labels.pod }} was OOMKilled."
      runbook  = "high-error-rate"
    }
    NodeCPUSaturation = {
      expr     = "(1 - avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))) > 0.9"
      for      = "PT15M"
      severity = 3
      summary  = "Node {{ $labels.instance }} CPU above 90% for 15 minutes."
      runbook  = "aks-node-not-ready"
    }
    PersistentVolumeFillingUp = {
      expr     = "kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes < 0.1"
      for      = "PT10M"
      severity = 2
      summary  = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} has less than 10% free space."
      runbook  = "aks-node-not-ready"
    }
    KyvernoAdmissionFailuresHigh = {
      expr     = "sum(increase(kyverno_admission_requests_total{request_allowed=\"false\"}[15m])) > 20"
      for      = "PT0M"
      severity = 3
      summary  = "Kyverno denied more than 20 admission requests in 15 minutes."
      runbook  = "image-admission-denied"
    }
    ArgoCDAppOutOfSync = {
      expr     = "sum by (name) (argocd_app_info{sync_status!=\"Synced\"}) > 0"
      for      = "PT30M"
      severity = 3
      summary  = "Argo CD application {{ $labels.name }} out of sync for 30 minutes."
      runbook  = "argocd-sync-failure"
    }
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "platform" {
  name                = "prg-${var.name}-platform"
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = azurerm_kubernetes_cluster.this.name
  scopes              = [var.monitor_workspace_id, azurerm_kubernetes_cluster.this.id]
  rule_group_enabled  = true
  interval            = "PT1M"
  description         = "Harborline platform alerts for ${var.name}"
  tags                = var.tags

  dynamic "rule" {
    for_each = local.platform_alerts
    content {
      alert       = rule.key
      enabled     = true
      expression  = rule.value.expr
      for         = rule.value.for
      severity    = rule.value.severity
      labels      = { team = "platform", environment = var.environment }
      annotations = {
        summary     = rule.value.summary
        runbook_url = "${local.runbook_base}/${rule.value.runbook}/"
      }

      action {
        action_group_id = var.action_group_id
      }

      alert_resolution {
        auto_resolved   = true
        time_to_resolve = "PT10M"
      }
    }
  }
}
