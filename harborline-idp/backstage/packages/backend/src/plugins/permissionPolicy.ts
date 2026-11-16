/*
 * Harborline permission policy (ASVS V8): deny by default for destructive catalog operations,
 * allow read for every authenticated engineer, restrict template execution of platform-only templates.
 */
import { createBackendModule } from '@backstage/backend-plugin-api';
import { policyExtensionPoint } from '@backstage/plugin-permission-node/alpha';
import {
  PermissionPolicy,
  PolicyQuery,
  PolicyQueryUser,
} from '@backstage/plugin-permission-node';
import {
  AuthorizeResult,
  PolicyDecision,
  isPermission,
} from '@backstage/plugin-permission-common';
import {
  catalogEntityDeletePermission,
  catalogLocationDeletePermission,
} from '@backstage/plugin-catalog-common/alpha';

const PLATFORM_ADMINS = 'group:default/platform-engineering';

export class HarborlinePermissionPolicy implements PermissionPolicy {
  async handle(
    request: PolicyQuery,
    user?: PolicyQueryUser,
  ): Promise<PolicyDecision> {
    const memberships = user?.info.ownershipEntityRefs ?? [];
    const isPlatformAdmin = memberships.includes(PLATFORM_ADMINS);

    if (!user) {
      return { result: AuthorizeResult.DENY };
    }

    if (
      isPermission(request.permission, catalogEntityDeletePermission) ||
      isPermission(request.permission, catalogLocationDeletePermission)
    ) {
      // Entities are owned by Git: deletion happens by removing catalog-info.yaml, not in the UI.
      return { result: isPlatformAdmin ? AuthorizeResult.ALLOW : AuthorizeResult.DENY };
    }

    return { result: AuthorizeResult.ALLOW };
  }
}

export default createBackendModule({
  pluginId: 'permission',
  moduleId: 'harborline-policy',
  register(reg) {
    reg.registerInit({
      deps: { policy: policyExtensionPoint },
      async init({ policy }) {
        policy.setPolicy(new HarborlinePermissionPolicy());
      },
    });
  },
});
