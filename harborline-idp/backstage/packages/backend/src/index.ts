/*
 * Harborline Backstage backend (new backend system).
 * Plugins are composed here; configuration lives in app-config*.yaml. No secrets in code or config:
 * they arrive as environment variables from Key Vault via the Secrets Store CSI driver.
 */
import { createBackend } from '@backstage/backend-defaults';

const backend = createBackend();

// Core
backend.add(import('@backstage/plugin-app-backend'));
backend.add(import('@backstage/plugin-proxy-backend'));

// Auth: Microsoft Entra ID only (no guest provider in production)
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-microsoft-provider'));

// Catalog: GitHub discovery for components, Microsoft Graph for users and groups
backend.add(import('@backstage/plugin-catalog-backend'));
backend.add(import('@backstage/plugin-catalog-backend-module-scaffolder-entity-model'));
backend.add(import('@backstage/plugin-catalog-backend-module-github'));
backend.add(import('@backstage/plugin-catalog-backend-module-msgraph'));

// Golden paths
backend.add(import('@backstage/plugin-scaffolder-backend'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-github'));

// Docs and search
backend.add(import('@backstage/plugin-techdocs-backend'));
backend.add(import('@backstage/plugin-search-backend'));
backend.add(import('@backstage/plugin-search-backend-module-pg'));
backend.add(import('@backstage/plugin-search-backend-module-catalog'));
backend.add(import('@backstage/plugin-search-backend-module-techdocs'));

// Runtime visibility: AKS clusters via workload identity (read-only RBAC)
backend.add(import('@backstage/plugin-kubernetes-backend'));

// Authorization: Harborline permission policy
backend.add(import('@backstage/plugin-permission-backend'));
backend.add(import('./plugins/permissionPolicy'));

backend.start();
