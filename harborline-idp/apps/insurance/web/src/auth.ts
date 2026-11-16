import { PublicClientApplication, InteractionRequiredAuthError, type AccountInfo } from "@azure/msal-browser";
import type { RuntimeConfig } from "./config";

/** Entra ID sign-in with MSAL (auth code + PKCE). Tokens stay in sessionStorage (cleared with the tab). */
export async function createMsal(cfg: RuntimeConfig): Promise<PublicClientApplication> {
  const msal = new PublicClientApplication({
    auth: {
      clientId: cfg.clientId,
      authority: `https://login.microsoftonline.com/${cfg.tenantId}`,
      redirectUri: window.location.origin,
      postLogoutRedirectUri: window.location.origin,
    },
    cache: { cacheLocation: "sessionStorage" },
  });
  await msal.initialize();
  const result = await msal.handleRedirectPromise();
  if (result?.account) msal.setActiveAccount(result.account);
  return msal;
}

export async function getAccessToken(msal: PublicClientApplication, scope: string): Promise<string> {
  const account: AccountInfo | null = msal.getActiveAccount() ?? msal.getAllAccounts()[0] ?? null;
  if (!account) {
    await msal.loginRedirect({ scopes: [scope] });
    throw new Error("redirecting to sign-in");
  }
  try {
    const r = await msal.acquireTokenSilent({ account, scopes: [scope] });
    return r.accessToken;
  } catch (e) {
    if (e instanceof InteractionRequiredAuthError) {
      await msal.acquireTokenRedirect({ account, scopes: [scope] });
    }
    throw e;
  }
}
