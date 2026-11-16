/**
 * app-gateway-waf — public entry point: Application Gateway WAF_v2 (zone-redundant, autoscaling) with
 * OWASP-based Default Rule Set 2.1 + Bot Manager in Prevention mode, geo-filter and per-client rate limiting.
 * TLS terminates with Key Vault certificates and is re-encrypted to the internal NGINX ingress (end-to-end TLS).
 */
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 4.40, < 5.0" }
  }
}

locals {
  frontend_ip   = "feip-public"
  https_port    = "port-443"
  http_port     = "port-80"
  backend_pool  = "be-ingress-internal"
  backend_https = "bes-ingress-https"
}

resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  domain_name_label   = var.name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_web_application_firewall_policy" "this" {
  name                = var.waf_policy_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 25
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.1"
    }
  }

  custom_rules {
    name      = "GeoAllowNorthAmerica"
    priority  = 10
    rule_type = "MatchRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "GeoMatch"
      negation_condition = true
      match_values       = var.allowed_countries
    }
  }

  custom_rules {
    name                 = "RateLimitPerClient"
    priority             = 20
    rule_type            = "RateLimitRule"
    action               = "Block"
    rate_limit_duration  = "OneMin"
    rate_limit_threshold = var.rate_limit_per_minute
    group_rate_limit_by  = "ClientAddr"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator     = "BeginsWith"
      match_values = ["/"]
    }
  }
}

resource "azurerm_application_gateway" "this" {
  name                              = var.name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  zones                             = var.zones
  firewall_policy_id                = azurerm_web_application_firewall_policy.this.id
  force_firewall_policy_association = true
  enable_http2                      = true
  tags                              = var.tags

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }

  gateway_ip_configuration {
    name      = "gwip"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip
    public_ip_address_id = azurerm_public_ip.this.id
  }

  frontend_port {
    name = local.https_port
    port = 443
  }

  frontend_port {
    name = local.http_port
    port = 80
  }

  backend_address_pool {
    name         = local.backend_pool
    ip_addresses = [var.backend_ip]
  }

  dynamic "ssl_certificate" {
    for_each = var.sites
    content {
      name                = "cert-${ssl_certificate.key}"
      key_vault_secret_id = ssl_certificate.value.certificate_secret_id
    }
  }

  dynamic "probe" {
    for_each = var.sites
    content {
      name                = "probe-${probe.key}"
      protocol            = "Https"
      host                = probe.value.host_name
      path                = probe.value.health_path
      interval            = 15
      timeout             = 10
      unhealthy_threshold = 3
      match {
        status_code = ["200-399"]
      }
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.sites
    content {
      name                  = "${local.backend_https}-${backend_http_settings.key}"
      protocol              = "Https"
      port                  = 443
      cookie_based_affinity = "Disabled"
      request_timeout       = 60
      host_name             = backend_http_settings.value.host_name
      probe_name            = "probe-${backend_http_settings.key}"
    }
  }

  dynamic "http_listener" {
    for_each = var.sites
    content {
      name                           = "lst-https-${http_listener.key}"
      frontend_ip_configuration_name = local.frontend_ip
      frontend_port_name             = local.https_port
      protocol                       = "Https"
      host_names                     = [http_listener.value.host_name]
      ssl_certificate_name           = "cert-${http_listener.key}"
      require_sni                    = true
    }
  }

  dynamic "http_listener" {
    for_each = var.sites
    content {
      name                           = "lst-http-${http_listener.key}"
      frontend_ip_configuration_name = local.frontend_ip
      frontend_port_name             = local.http_port
      protocol                       = "Http"
      host_names                     = [http_listener.value.host_name]
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.sites
    content {
      name                 = "redirect-${redirect_configuration.key}"
      redirect_type        = "Permanent"
      target_listener_name = "lst-https-${redirect_configuration.key}"
      include_path         = true
      include_query_string = true
    }
  }

  dynamic "request_routing_rule" {
    for_each = { for i, k in keys(var.sites) : k => i }
    content {
      name                       = "rule-https-${request_routing_rule.key}"
      rule_type                  = "Basic"
      priority                   = 100 + request_routing_rule.value * 10
      http_listener_name         = "lst-https-${request_routing_rule.key}"
      backend_address_pool_name  = local.backend_pool
      backend_http_settings_name = "${local.backend_https}-${request_routing_rule.key}"
      rewrite_rule_set_name      = "security-headers"
    }
  }

  dynamic "request_routing_rule" {
    for_each = { for i, k in keys(var.sites) : k => i }
    content {
      name                        = "rule-http-${request_routing_rule.key}"
      rule_type                   = "Basic"
      priority                    = 500 + request_routing_rule.value * 10
      http_listener_name          = "lst-http-${request_routing_rule.key}"
      redirect_configuration_name = "redirect-${request_routing_rule.key}"
    }
  }

  rewrite_rule_set {
    name = "security-headers"

    rewrite_rule {
      name          = "add-security-headers"
      rule_sequence = 100

      response_header_configuration {
        header_name  = "Strict-Transport-Security"
        header_value = "max-age=31536000; includeSubDomains"
      }

      response_header_configuration {
        header_name  = "X-Content-Type-Options"
        header_value = "nosniff"
      }

      response_header_configuration {
        header_name  = "Referrer-Policy"
        header_value = "strict-origin-when-cross-origin"
      }

      response_header_configuration {
        header_name  = "Server"
        header_value = ""
      }
    }
  }

  depends_on = [azurerm_role_assignment.kv_secrets]
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_application_gateway.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

variable "name" {
  description = "Application Gateway name."
  type        = string
}

variable "waf_policy_name" {
  description = "WAF policy name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group."
  type        = string
}

variable "zones" {
  description = "Availability zones."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "subnet_id" {
  description = "Dedicated App Gateway subnet."
  type        = string
}

variable "backend_ip" {
  description = "Internal NGINX ingress load balancer IP."
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault holding TLS certificates."
  type        = string
}

variable "sites" {
  description = "Map of site key => { host_name, certificate_secret_id (versionless), health_path }."
  type        = map(object({
    host_name             = string
    certificate_secret_id = string
    health_path           = optional(string, "/healthz")
  }))
}

variable "allowed_countries" {
  description = "ISO country codes allowed to reach public sites."
  type        = list(string)
  default     = ["CA", "US"]
}

variable "rate_limit_per_minute" {
  description = "Per-client request limit per minute."
  type        = number
  default     = 600
}

variable "min_capacity" {
  description = "Autoscale minimum instances (>= 2 in prod for zone redundancy)."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Autoscale maximum instances."
  type        = number
  default     = 10
}

variable "log_analytics_workspace_id" {
  description = "Workspace for access and WAF logs."
  type        = string
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}

output "public_ip" {
  description = "Public IP address (point DNS here)."
  value       = azurerm_public_ip.this.ip_address
}

output "id" {
  description = "Application Gateway ID."
  value       = azurerm_application_gateway.this.id
}
