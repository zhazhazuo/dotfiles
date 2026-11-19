// Invoice list and detail. Reads through the cache. The /v2/invoices endpoint is not built.
import { cacheKey, invalidateTenant, read, write } from "./cache.ts";
import { orderWithTaxCents, type Order } from "./orders.ts";

export type Invoice = {
  id: string;
  tenantId: string;
  amountCents: number;
  status: "pending" | "paid" | "refunded";
};

export const PAGE_SIZE = 25;

const byTenant = new Map<string, Invoice[]>();

export function seed(invoices: Invoice[]): void {
  for (const invoice of invoices) {
    const list = byTenant.get(invoice.tenantId) ?? [];
    list.push(invoice);
    byTenant.set(invoice.tenantId, list);
  }
}

export function listPage(tenantId: string, page: number): Invoice[] {
  const key = cacheKey(tenantId, page);
  const hit = read<Invoice[]>(key);
  if (hit) return hit;
  const all = [...(byTenant.get(tenantId) ?? [])].sort((a, b) => b.id.localeCompare(a.id));
  const slice = all.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  write(key, slice);
  return slice;
}

export function pageTotal(invoices: Invoice[]): number {
  const open = invoices.filter((invoice) => invoice.status !== "refunded");
  const order: Order = {
    id: "page",
    amountCents: open.reduce((sum, invoice) => sum + invoice.amountCents, 0),
    status: "pending",
  };
  return orderWithTaxCents(order);
}

export function refund(tenantId: string, invoiceId: string): void {
  for (const invoice of byTenant.get(tenantId) ?? []) {
    if (invoice.id === invoiceId) invoice.status = "refunded";
  }
  invalidateTenant(tenantId);
}
