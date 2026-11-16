import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiError, createApi, formatCad } from "./api";

afterEach(() => vi.unstubAllGlobals());

describe("api client", () => {
  it("sends a bearer token and parses JSON", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify([]), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    const api = createApi("/api", async () => "t0k3n");
    await expect(api.listPolicies()).resolves.toEqual([]);
    const [, init] = fetchMock.mock.calls[0];
    expect(init.headers.Authorization).toBe("Bearer t0k3n");
  });

  it("surfaces RFC 9457 problems as ApiError", async () => {
    const problem = { title: "Conflict", status: 409, detail: "quote cannot be bound", correlation_id: "abc" };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(JSON.stringify(problem), { status: 409 })));
    const api = createApi("/api", async () => "t");
    await expect(api.bind("q1")).rejects.toBeInstanceOf(ApiError);
  });
});

describe("formatCad", () => {
  it("formats Canadian dollars", () => {
    expect(formatCad("1234.5")).toContain("1,234.50");
  });
});
