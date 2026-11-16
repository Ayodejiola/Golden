# Disaster recovery

**Strategy:** zone failures are absorbed automatically (zone-redundant everything). A **regional** failure of Canada
Central is handled by **rebuilding the platform in Canada East from Git** and restoring data from geo-redundant
backups. Targets for tier-1: **RTO 4 h, RPO 15 min** (PostgreSQL geo-restore RPO is typically < 1 h; tier-1 data
accepted at ≤ 1 h until warm standby — tracked on the roadmap).

| Component | Zone failure | Region failure |
|---|---|---|
| AKS | Pods rescheduled across 3 zones (topology spread, PDBs) | Apply `platform` stack with `location = canadaeast`, bootstrap Argo CD; workloads sync from Git |
| PostgreSQL | Automatic ZR HA failover (~60–120 s) | Geo-restore to Canada East from geo-redundant backup |
| Service Bus | Premium is zone-redundant | Geo-DR alias pairing (metadata) to a Canada East namespace; in-flight messages may be lost → outbox re-publishes unpublished events |
| ACR | Zone-redundant | Geo-replica in Canada East already holds every image |
| Key Vault | Zone-redundant | Paired-region read-only failover; certificates re-imported if needed |
| App Gateway / DNS | Zonal instances | New WAF in DR spoke; public DNS TTL 300 s switch |
| Terraform state / Git | GZRS storage; GitHub SaaS | Read-access geo-redundant; GitHub independent of Azure |

## Regional failover procedure (summary)

1. IC declares DR (SEV1). Freeze all non-DR changes.
2. `connectivity`: apply DR hub (`env/dr.tfvars`) if not pre-provisioned.
3. `platform`: apply with DR variables (Canada East, DR spoke CIDR `10.40.0.0/16`).
4. `workload-insurance`: create PostgreSQL via geo-restore (`az postgres flexible-server geo-restore`) and import into
   state; Service Bus: break pairing / fail over alias.
5. Run `platform-bootstrap.yml` for the DR cluster; Argo CD syncs add-ons, tenants and workloads (images already in the
   ACR geo-replica).
6. Update workload values with DR endpoints (prepared `values-dr.yaml` overlays), switch public DNS to the DR WAF.
7. Validate SLIs and business smoke tests; communicate.

## Testing

| Test | Frequency | Last run |
|---|---|---|
| PostgreSQL point-in-time restore to a scratch server | Monthly | Recorded in DR log |
| Zone failure simulation (cordon/drain one zone in stg) | Quarterly | — |
| Full regional rebuild of stg in Canada East | Twice a year | — |
| Backup restore of Key Vault secrets (soft-delete recovery) | Yearly | — |

Results and timings go into the DR log; RTO/RPO misses become roadmap items.
