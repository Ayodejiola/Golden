/** Runtime configuration served by NGINX at /config.json (rendered from env at container start),
 * so one image is promoted unchanged across dev → stg → prod. */
export interface RuntimeConfig {
  apiBase: string;
  tenantId: string;
  clientId: string;
  apiScope: string;
}

let cached: RuntimeConfig | null = null;

export async function loadConfig(): Promise<RuntimeConfig> {
  if (cached) return cached;
  const res = await fetch("/config.json", { cache: "no-store" });
  if (!res.ok) throw new Error(`config load failed: ${res.status}`);
  cached = (await res.json()) as RuntimeConfig;
  return cached;
}
