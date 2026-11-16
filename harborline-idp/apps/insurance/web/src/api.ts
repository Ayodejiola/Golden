export interface Problem {
  title: string;
  status: number;
  detail?: string | null;
  correlation_id?: string | null;
}

export class ApiError extends Error {
  constructor(public readonly problem: Problem) {
    super(problem.detail ?? problem.title);
  }
}

export type TokenProvider = () => Promise<string>;

/** Thin fetch wrapper: bearer token, JSON, RFC 9457 problem details, correlation id for support. */
export function createApi(apiBase: string, token: TokenProvider) {
  async function call<T>(method: string, path: string, body?: unknown): Promise<T> {
    const res = await fetch(`${apiBase}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${await token()}`,
        "Content-Type": "application/json",
        "x-correlation-id": crypto.randomUUID(),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!res.ok) {
      const problem = (await res.json().catch(() => ({ title: res.statusText, status: res.status }))) as Problem;
      throw new ApiError(problem);
    }
    return (await res.json()) as T;
  }
  return {
    createQuote: (req: unknown) => call<Quote>("POST", "/v1/quotes", req),
    bind: (quoteId: string) => call<Policy>("POST", "/v1/policies", { quote_id: quoteId, accept_terms: true }),
    listPolicies: () => call<Policy[]>("GET", "/v1/policies"),
    submitClaim: (req: unknown) => call<Claim>("POST", "/v1/claims", req),
  };
}

export type Api = ReturnType<typeof createApi>;

export interface Quote {
  id: string;
  product: "auto" | "home";
  status: "quoted" | "referred" | "declined" | "bound";
  premium: { annual_premium: string; monthly_premium: string; factors: Record<string, string> } | null;
  reasons: string[];
  expires_at: string;
}

export interface Policy {
  id: string;
  policy_number: string;
  product: "auto" | "home";
  status: string;
  effective_date: string;
  expiry_date: string;
  annual_premium: string;
}

export interface Claim {
  id: string;
  claim_number: string;
  policy_number: string;
  status: string;
  loss_type: string;
  loss_date: string;
  triage_outcome: string | null;
}

export function formatCad(amount: string | number): string {
  return new Intl.NumberFormat("en-CA", { style: "currency", currency: "CAD" }).format(Number(amount));
}
