import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { createMsal, getAccessToken } from "./auth";
import { createApi } from "./api";
import { loadConfig } from "./config";
import "./styles.css";

async function start() {
  const cfg = await loadConfig();
  // "local" is only ever served by the local compose stack; the API refuses AUTH_REQUIRED=false elsewhere.
  if (cfg.clientId === "local") {
    const api = createApi(cfg.apiBase, async () => "local-dev");
    render(api, () => window.location.reload());
    return;
  }
  const msal = await createMsal(cfg);
  const api = createApi(cfg.apiBase, () => getAccessToken(msal, cfg.apiScope));
  render(api, () => void msal.logoutRedirect());
}

function render(api: ReturnType<typeof createApi>, onSignOut: () => void) {
  createRoot(document.getElementById("root")!).render(
    <StrictMode>
      <App api={api} onSignOut={onSignOut} />
    </StrictMode>,
  );
}

start().catch((e) => {
  document.getElementById("root")!.textContent = "The portal is unavailable. Please try again shortly.";
  console.error(e);
});
