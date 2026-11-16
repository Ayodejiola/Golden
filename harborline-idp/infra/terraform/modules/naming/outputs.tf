output "names" {
  description = "Map of resource type => compliant resource name."
  value       = local.names
}

output "tags" {
  description = "Mandatory tag set (see docs/governance/standards.md)."
  value       = local.tags
}

output "region_short" {
  description = "Short code for the location."
  value       = local.loc
}

output "base" {
  description = "Name base <workload>-<env>-<region>-<instance> for ad-hoc names."
  value       = local.base
}
