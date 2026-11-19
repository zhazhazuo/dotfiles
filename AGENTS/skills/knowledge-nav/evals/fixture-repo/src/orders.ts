export type Order = { id: string; amountCents: number; status: "pending" | "paid" };
export const TAX_RATE = 0.2;
export function processOrder(order: Order): Order {
  if (order.amountCents <= 0) throw new Error(`bad amount for ${order.id}`);
  return { ...order, status: "paid" };
}
export function orderWithTaxCents(order: Order): number {
  return Math.round(order.amountCents * (1 + TAX_RATE));
}
