// HTTP routes. The /v2/invoices endpoint is deliberately absent.
import { listPage, pageTotal, refund } from "../invoices.ts";
import { requireIdentity, type Request } from "../auth/middleware.ts";

export type Response = { status: number; body: unknown };

const routes: Record<string, (request: Request, params: string[]) => Response> = {
  "GET /v1/orders": () => ({ status: 200, body: [] }),
  "GET /v1/invoices/:tenant/:page": (request, params) => {
    requireIdentity(request);
    const invoices = listPage(params[0], Number(params[1]));
    return { status: 200, body: { invoices, total: pageTotal(invoices) } };
  },
  "POST /v1/invoices/:tenant/:id/refund": (request, params) => {
    requireIdentity(request);
    refund(params[0], params[1]);
    return { status: 204, body: null };
  },
};

export function handle(request: Request, method: string, path: string): Response {
  const parts = path.split("/").filter(Boolean);
  for (const [pattern, handler] of Object.entries(routes)) {
    const [routeMethod, routePath] = pattern.split(" ");
    if (routeMethod !== method) continue;
    const patternParts = routePath.split("/").filter(Boolean);
    if (patternParts.length !== parts.length) continue;
    const params: string[] = [];
    const matches = patternParts.every((part, index) => {
      if (part.startsWith(":")) {
        params.push(parts[index]);
        return true;
      }
      return part === parts[index];
    });
    if (matches) return handler(request, params);
  }
  return { status: 404, body: { error: "not found" } };
}
