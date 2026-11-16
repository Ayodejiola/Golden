import { useState, type FormEvent } from "react";
import { ApiError, formatCad, type Api, type Quote } from "../api";

const PROVINCES = ["AB", "BC", "MB", "NB", "NL", "NS", "ON", "PE", "QC", "SK"];

export function QuotePage({ api }: { api: Api }) {
  const [product, setProduct] = useState<"auto" | "home">("auto");
  const [quote, setQuote] = useState<Quote | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [bound, setBound] = useState<string | null>(null);

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const risk =
      product === "auto"
        ? { kind: "auto", vehicle_year: Number(f.get("vehicle_year")), vehicle_value: String(f.get("vehicle_value")),
            annual_km: Number(f.get("annual_km")), prior_claims: Number(f.get("prior_claims")) }
        : { kind: "home", dwelling_value: String(f.get("dwelling_value")), year_built: Number(f.get("year_built")),
            construction: String(f.get("construction")), prior_claims: Number(f.get("prior_claims")) };
    setBusy(true);
    setError(null);
    setBound(null);
    try {
      setQuote(
        await api.createQuote({
          product,
          insured: {
            first_name: f.get("first_name"), last_name: f.get("last_name"), email: f.get("email"),
            date_of_birth: f.get("date_of_birth"), province: f.get("province"),
          },
          risk,
          deductible: Number(f.get("deductible")),
          effective_date: f.get("effective_date"),
        }),
      );
    } catch (err) {
      setError(err instanceof ApiError ? `${err.message} (ref ${err.problem.correlation_id ?? "n/a"})` : "Request failed");
    } finally {
      setBusy(false);
    }
  }

  async function bind() {
    if (!quote) return;
    try {
      const p = await api.bind(quote.id);
      setBound(p.policy_number);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Bind failed");
    }
  }

  return (
    <section>
      <h1>Get a quote</h1>
      <div role="radiogroup" aria-label="Product" className="row">
        {(["auto", "home"] as const).map((p) => (
          <label key={p}>
            <input type="radio" name="product" checked={product === p} onChange={() => setProduct(p)} /> {p}
          </label>
        ))}
      </div>
      <form onSubmit={submit} className="grid">
        <input name="first_name" placeholder="First name" required maxLength={80} />
        <input name="last_name" placeholder="Last name" required maxLength={80} />
        <input name="email" type="email" placeholder="Email" required maxLength={254} />
        <label>Date of birth <input name="date_of_birth" type="date" required /></label>
        <select name="province" defaultValue="NB">{PROVINCES.map((p) => <option key={p}>{p}</option>)}</select>
        {product === "auto" ? (
          <>
            <input name="vehicle_year" type="number" placeholder="Vehicle year" required min={1980} />
            <input name="vehicle_value" type="number" placeholder="Vehicle value (CAD)" required min={0} />
            <input name="annual_km" type="number" placeholder="Annual km" required min={0} />
          </>
        ) : (
          <>
            <input name="dwelling_value" type="number" placeholder="Dwelling value (CAD)" required min={50000} />
            <input name="year_built" type="number" placeholder="Year built" required min={1800} />
            <select name="construction" defaultValue="wood"><option>wood</option><option>masonry</option></select>
          </>
        )}
        <input name="prior_claims" type="number" placeholder="Prior claims" required min={0} defaultValue={0} />
        <select name="deductible" defaultValue="1000"><option>500</option><option>1000</option><option>2500</option></select>
        <label>Start date <input name="effective_date" type="date" required /></label>
        <button type="submit" disabled={busy}>{busy ? "Rating…" : "Get quote"}</button>
      </form>
      {error && <p role="alert" className="error">{error}</p>}
      {quote && (
        <div className="card" aria-live="polite">
          <h2>Quote {quote.status}</h2>
          {quote.premium && (
            <p>{formatCad(quote.premium.annual_premium)} / year ({formatCad(quote.premium.monthly_premium)} / month)</p>
          )}
          {quote.reasons.length > 0 && <ul>{quote.reasons.map((r) => <li key={r}>{r}</li>)}</ul>}
          {quote.status === "quoted" && !bound && <button onClick={bind}>Accept and bind</button>}
          {bound && <p>Policy <strong>{bound}</strong> is active.</p>}
        </div>
      )}
    </section>
  );
}
