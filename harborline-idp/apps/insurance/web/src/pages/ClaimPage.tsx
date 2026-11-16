import { useState, type FormEvent } from "react";
import { ApiError, type Api, type Claim } from "../api";

const LOSS_TYPES = ["collision", "theft", "fire", "water", "weather", "liability"];

export function ClaimPage({ api }: { api: Api }) {
  const [claim, setClaim] = useState<Claim | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    setError(null);
    try {
      setClaim(
        await api.submitClaim({
          policy_number: f.get("policy_number"),
          loss_date: f.get("loss_date"),
          loss_type: f.get("loss_type"),
          description: f.get("description"),
          estimated_amount: String(f.get("estimated_amount")),
        }),
      );
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Submission failed");
    }
  }

  return (
    <section>
      <h1>Report a claim</h1>
      <form onSubmit={submit} className="grid">
        <input name="policy_number" placeholder="HBL-AU-2026-100001" required pattern="HBL-(AU|HO)-\d{4}-\d{6}" />
        <label>Date of loss <input name="loss_date" type="date" required /></label>
        <select name="loss_type">{LOSS_TYPES.map((t) => <option key={t}>{t}</option>)}</select>
        <input name="estimated_amount" type="number" min={0} step="0.01" placeholder="Estimated amount (CAD)" required />
        <textarea name="description" minLength={10} maxLength={2000} placeholder="What happened?" required />
        <button type="submit">Submit claim</button>
      </form>
      {error && <p role="alert" className="error">{error}</p>}
      {claim && (
        <div className="card" aria-live="polite">
          <h2>Claim {claim.claim_number} received</h2>
          <p>We are reviewing it now. You will be contacted by an adjuster if more information is needed.</p>
        </div>
      )}
    </section>
  );
}
