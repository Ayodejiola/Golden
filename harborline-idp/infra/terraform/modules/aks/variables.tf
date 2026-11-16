variable "name" {
  description = "Cluster name."
  type        = string
}

variable "environment" {
  description = "Environment (dev, stg, prod)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cluster."
  type        = string
}

variable "node_resource_group_name" {
  description = "Managed node resource group name."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. 1.33). Patch versions are applied by the auto-upgrade channel."
  type        = string
  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "Use a minor version only, e.g. 1.33."
  }
}

variable "sku_tier" {
  description = "AKS tier: Free (dev only), Standard (uptime SLA) or Premium (LTS)."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "zones" {
  description = "Availability zones for node pools."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "vnet_id" {
  description = "Spoke VNet ID (control-plane identity gets Network Contributor)."
  type        = string
}

variable "system_subnet_id" {
  description = "Subnet for the system node pool."
  type        = string
}

variable "user_subnet_id" {
  description = "Subnet for user node pools."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Hub private DNS zone for the API server (privatelink.<region>.azmk8s.io)."
  type        = string
}

variable "pod_cidr" {
  description = "Overlay pod CIDR (not routable on the VNet)."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service CIDR."
  type        = string
  default     = "172.16.0.0/16"
}

variable "acr_id" {
  description = "Container registry ID (kubelet gets AcrPull)."
  type        = string
}

variable "admin_group_object_id" {
  description = "Entra group with cluster-admin (platform SRE, PIM-eligible)."
  type        = string
}

variable "reader_group_object_ids" {
  description = "Entra groups with cluster-wide read access."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID."
  type        = string
}

variable "monitor_workspace_id" {
  description = "Azure Monitor workspace ID (managed Prometheus)."
  type        = string
}

variable "action_group_id" {
  description = "Action group for platform alerts."
  type        = string
}

variable "host_encryption_enabled" {
  description = "Encryption at host (requires Microsoft.Compute/EncryptionAtHost feature registration)."
  type        = bool
  default     = true
}

variable "system_pool" {
  description = "System pool sizing."
  type        = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    os_disk_size_gb = optional(number, 128)
  })
}

variable "user_pools" {
  description = "Map of user node pools."
  type        = map(object({
    vm_size         = string
    min_count       = number
    max_count       = number
    os_disk_size_gb = optional(number, 128)
    labels          = optional(map(string), {})
    taints          = optional(list(string), [])
  }))
}

variable "app_routing_dns_zone_ids" {
  description = "DNS zones the app routing add-on may manage (empty: TLS/DNS handled at App Gateway)."
  type        = list(string)
  default     = []
}

variable "kms" {
  description = "Optional KMS v2 etcd encryption with a customer-managed key. Private network access requires API Server VNet Integration (see ADR-0001)."
  type        = object({
    key_id         = string
    network_access = string
  })
  default = null
}

variable "maintenance" {
  description = "Planned maintenance window (local time with offset)."
  type        = object({
    day_of_week = string
    start_time  = string
    utc_offset  = string
  })
  default = {
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "-04:00"
  }
}

variable "diagnostic_categories" {
  description = "Control-plane log categories sent to Log Analytics."
  type        = list(string)
  default     = ["kube-audit-admin", "kube-apiserver", "kube-controller-manager", "kube-scheduler", "cluster-autoscaler", "guard"]
}

variable "tags" {
  description = "Tags."
  type        = map(string)
}
