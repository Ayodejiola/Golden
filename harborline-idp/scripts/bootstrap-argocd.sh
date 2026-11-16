#!/usr/bin/env bash
# One-time Argo CD installation on a private AKS cluster, run from the platform-bootstrap workflow on a
# VNet-injected runner (or from Bastion). After this, Argo CD manages itself and everything else from Git.
#
#   scripts/bootstrap-argocd.sh <env>        # env: dev | stg | prod
set -euo pipefail

ENV="${1:?usage: $0 <dev|stg|prod>}"
CLUSTER="aks-plat-${ENV}-cac-01"
RG="rg-plat-${ENV}-cac-01"
KV="kv-hbl-plat-${ENV}-cac01"
ACR="acrhblmgmtsharedcac01.azurecr.io"
CHART_VERSION="$(yq '.spec.generators[0].list.elements[] | select(.name == "argocd") | .version' "gitops/clusters/${ENV}/addons-helm.yaml")"
ROOT="$(git rev-parse --show-toplevel)"

echo "==> Credentials for ${CLUSTER} (Entra ID, kubelogin)"
az aks get-credentials -g "$RG" -n "$CLUSTER" --overwrite-existing --file "${RUNNER_TEMP:-/tmp}/kubeconfig"
export KUBECONFIG="${RUNNER_TEMP:-/tmp}/kubeconfig"
kubelogin convert-kubeconfig -l azurecli

echo "==> Namespace and Git credentials (GitHub App) from Key Vault"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
APP_ID="$(az keyvault secret show --vault-name "$KV" -n argocd-github-app-id --query value -o tsv)"
INSTALL_ID="$(az keyvault secret show --vault-name "$KV" -n argocd-github-app-installation-id --query value -o tsv)"
az keyvault secret show --vault-name "$KV" -n argocd-github-app-private-key --query value -o tsv \
  | kubectl -n argocd create secret generic repo-harborline-idp \
      --from-literal=type=git \
      --from-literal=url=https://github.com/harborline/harborline-idp.git \
      --from-literal=githubAppID="$APP_ID" \
      --from-literal=githubAppInstallationID="$INSTALL_ID" \
      --from-file=githubAppPrivateKey=/dev/stdin \
      --dry-run=client -o yaml \
  | kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
  | kubectl apply -f -

echo "==> Install Argo CD ${CHART_VERSION} from the ACR mirror"
az acr login -n "${ACR%%.*}" --expose-token --output tsv --query accessToken \
  | helm registry login "$ACR" --username 00000000-0000-0000-0000-000000000000 --password-stdin
helm upgrade --install argocd "oci://${ACR}/helm/argo-cd" --version "$CHART_VERSION" \
  --namespace argocd \
  -f "${ROOT}/gitops/addons/argocd/values.yaml" \
  -f "${ROOT}/gitops/addons/argocd/values-${ENV}.yaml" \
  --wait --timeout 10m

echo "==> AppProjects and root application"
kubectl apply -k "${ROOT}/gitops/projects"
kubectl apply -f "${ROOT}/gitops/bootstrap/root-${ENV}.yaml"

echo "Argo CD is now managing ${CLUSTER}. Watch: kubectl -n argocd get applications -w"
