SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

STACKS      := bootstrap connectivity management platform workload-insurance
TF_ROOT     := infra/terraform
CHART       := platform/charts/golden-service
PY_APPS     := apps/insurance/policy-api apps/insurance/claims-worker
ENVS        := dev stg prod

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## ---------- aggregate ----------
.PHONY: validate
validate: lint-yaml tf-validate tf-test policy-test k8s-validate app-test guard-test mcp-test docs-build ## Run every offline check

## ---------- terraform ----------
.PHONY: tf-fmt
tf-fmt: ## Format all Terraform
	terraform fmt -recursive $(TF_ROOT)

.PHONY: tf-validate
tf-validate: ## fmt-check, init (no backend), validate and tflint every stack
	terraform fmt -check -recursive $(TF_ROOT)
	@for s in $(STACKS); do \
	  echo "==> $$s"; \
	  terraform -chdir=$(TF_ROOT)/stacks/$$s init -backend=false -input=false >/dev/null; \
	  terraform -chdir=$(TF_ROOT)/stacks/$$s validate; \
	  (cd $(TF_ROOT)/stacks/$$s && tflint --config=$(CURDIR)/.tflint.hcl --init >/dev/null && tflint --config=$(CURDIR)/.tflint.hcl); \
	done

.PHONY: tf-test
tf-test: ## terraform test for pure modules (naming)
	terraform -chdir=$(TF_ROOT)/modules/naming init -backend=false >/dev/null
	terraform -chdir=$(TF_ROOT)/modules/naming test

.PHONY: checkov
checkov: ## Static security scan of Terraform, Helm and workflows
	checkov -d . --config-file .checkov.yaml

## ---------- kubernetes ----------
.PHONY: helm-lint
helm-lint: ## Lint and render the golden-service chart for every workload values file
	helm lint $(CHART) --strict -f $(CHART)/ci/test-values.yaml
	@for f in $$(find gitops/workloads -name values.yaml); do \
	  echo "==> $$f"; helm template ci $(CHART) -f $$f >/dev/null; \
	done

.PHONY: k8s-validate
k8s-validate: helm-lint ## Schema-validate rendered manifests and GitOps resources with kubeconform
	@mkdir -p .out
	@for f in $$(find gitops/workloads -name values.yaml); do \
	  helm template ci $(CHART) -f $$f; echo "---"; \
	done > .out/rendered.yaml
	kubeconform -strict -summary -ignore-missing-schemas \
	  -schema-location default \
	  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
	  .out/rendered.yaml gitops/ platform/policies/kyverno/

.PHONY: policy-test
policy-test: ## Kyverno CLI tests + Conftest for Terraform plans
	kyverno test platform/policies/kyverno/tests
	conftest verify --policy platform/policies/conftest

## ---------- apps ----------
.PHONY: app-test
app-test: ## Unit tests for the insurance Python services
	@for a in $(PY_APPS); do echo "==> $$a"; (cd $$a && python3 -m pytest -q); done

.PHONY: app-lint
app-lint: ## Ruff + mypy for the Python services
	ruff check apps ai
	ruff format --check apps ai

.PHONY: app-up
app-up: ## Run the insurance app locally (docker compose)
	docker compose -f apps/insurance/docker-compose.yaml up --build -d

.PHONY: app-down
app-down: ## Stop the local insurance app
	docker compose -f apps/insurance/docker-compose.yaml down -v

## ---------- AI guardrails ----------
.PHONY: guard-test
guard-test: ## Test the Claude Code guard hook
	python3 -m pytest -q .claude/hooks/tests

.PHONY: mcp-test
mcp-test: ## Test the platform-catalog MCP server
	python3 -m pytest -q ai/mcp-servers/platform-catalog/tests

## ---------- docs ----------
.PHONY: docs-build
docs-build: ## Build the TechDocs/MkDocs site in strict mode
	mkdocs build --strict

.PHONY: docs-serve
docs-serve: ## Serve docs locally
	mkdocs serve

.PHONY: diagrams
diagrams: ## Render Mermaid sources in docs/architecture/diagrams to SVG
	@for f in docs/architecture/diagrams/*.mmd; do \
	  mmdc -i $$f -o $${f%.mmd}.svg -b transparent; \
	done

.PHONY: lint-yaml
lint-yaml: ## yamllint the repository
	yamllint -c .yamllint.yaml .

## ---------- supply chain hygiene ----------
.PHONY: pin-actions
pin-actions: ## Pin all GitHub Actions to commit SHAs (requires pinact)
	pinact run

.PHONY: lock
lock: ## Generate dependency lock files
	@for a in $(PY_APPS); do (cd $$a && uv pip compile pyproject.toml --generate-hashes -o requirements.lock); done
	cd apps/insurance/web && npm install --package-lock-only
	@for s in $(STACKS); do terraform -chdir=$(TF_ROOT)/stacks/$$s providers lock -platform=linux_amd64 -platform=darwin_arm64; done
