// Order intake for the eval fixture. Small on purpose: the routing eval needs a
// plausible tree, not a real service.

export type Order = {
  id: string;
  amountCents: number;
  status: "pending" | "paid" | "refunded";
};

export const TAX_RATE = 0.2;

export function processOrder(order: Order): Order {
  if (order.amountCents <= 0) {
    throw new Error(`Order amount must be positive for ${order.id}`);
  }
  return { ...order, status: "paid" };
}

export function orderWithTaxCents(order: Order): number {
  return Math.round(order.amountCents * (1 + TAX_RATE));
}
