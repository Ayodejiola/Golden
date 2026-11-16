# Day-2 operations

## Routine calendar

| Cadence | Task | Owner |
|---|---|---|
| Daily | Review drift-detection results; triage Defender high alerts | Platform primary |
| Weekly | Alert noise review; Dependabot/Renovate PR merge; mirror rescans | Platform + SRE |
| Weekly (auto) | AKS patch + node image upgrades in maintenance window (Sun 02:00 AT) | AKS |
| Monthly | AKS minor version check; exception/waiver review; cost review; PITR test | Platform, Security, FinOps |
| Quarterly | Threat model review; WAF assessment; DR zone test; access reviews (PIM, groups) | Security, SRE, Architecture |

## Drift

`drift-detection.yml` plans every stack nightly with read-only identities. On drift:

1. Read the plan in the run summary and the opened issue.
2. Identify the actor in the Azure activity log (`AzureActivity | where ResourceId contains '<resource>'`).
3. Either **codify** the change (PR) or **revert** by re-running the apply job for that stack.
4. Unapproved manual change in prod is a policy violation → raise with the actor's manager and Security.

## Scaling the platform

- New environment: copy `env/<env>.tfvars` for `platform` and workload stacks, allocate a /16 in IPAM, add a
  `gitops/clusters/<env>` folder, add GitHub environment + runner group, bootstrap Argo CD.
- New region: add region short code to the `naming` module validation and a private DNS zone for the AKS API.

## Add-on upgrades

Bump chart version in `gitops/clusters/dev/addons-helm.yaml` (after mirroring it), watch health for a week, then stg,
then prod. Kyverno and Argo CD upgrades require reading upstream release notes for CRD and policy behaviour changes.

## Capacity

Watch *Platform overview* → requested vs allocatable. Above 70% sustained requests in prod: raise pool `max_count`
or add a pool via Terraform. Tenant quota increases go through the platform request issue template.
