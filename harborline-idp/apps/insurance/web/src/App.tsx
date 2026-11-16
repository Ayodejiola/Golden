import { useState } from "react";
import type { Api } from "./api";
import { QuotePage } from "./pages/QuotePage";
import { PoliciesPage } from "./pages/PoliciesPage";
import { ClaimPage } from "./pages/ClaimPage";

type Tab = "quote" | "policies" | "claim";

export function App({ api, onSignOut }: { api: Api; onSignOut: () => void }) {
  const [tab, setTab] = useState<Tab>("quote");
  return (
    <div className="shell">
      <header>
        <strong>Harborline</strong> Policy Portal
        <nav aria-label="Main">
          {(["quote", "policies", "claim"] as Tab[]).map((t) => (
            <button key={t} aria-current={tab === t ? "page" : undefined} onClick={() => setTab(t)}>
              {t === "quote" ? "Get a quote" : t === "policies" ? "My policies" : "Report a claim"}
            </button>
          ))}
          <button className="link" onClick={onSignOut}>Sign out</button>
        </nav>
      </header>
      <main>
        {tab === "quote" && <QuotePage api={api} />}
        {tab === "policies" && <PoliciesPage api={api} />}
        {tab === "claim" && <ClaimPage api={api} />}
      </main>
      <footer>Reference application for the Harborline golden path. Synthetic data only.</footer>
    </div>
  );
}
