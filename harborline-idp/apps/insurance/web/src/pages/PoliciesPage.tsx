import { useEffect, useState } from "react";
import { formatCad, type Api, type Policy } from "../api";

export function PoliciesPage({ api }: { api: Api }) {
  const [policies, setPolicies] = useState<Policy[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.listPolicies().then(setPolicies).catch(() => setError("Could not load policies"));
  }, [api]);

  if (error) return <p role="alert" className="error">{error}</p>;
  if (!policies) return <p>Loading…</p>;
  return (
    <section>
      <h1>My policies</h1>
      {policies.length === 0 ? (
        <p>No policies yet.</p>
      ) : (
        <table>
          <thead>
            <tr><th>Policy</th><th>Product</th><th>Status</th><th>Term</th><th>Premium</th></tr>
          </thead>
          <tbody>
            {policies.map((p) => (
              <tr key={p.id}>
                <td>{p.policy_number}</td>
                <td>{p.product}</td>
                <td>{p.status}</td>
                <td>{p.effective_date} → {p.expiry_date}</td>
                <td>{formatCad(p.annual_premium)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
