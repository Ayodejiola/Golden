import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

// Local dev proxies /api to the policy-api on :8080 (docker compose); production uses the same-origin ingress.
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, proxy: { "/api": "http://localhost:8080", "/config.json": "http://localhost:8081" } },
  build: { sourcemap: false, outDir: "dist" },
  test: { environment: "node" },
});
