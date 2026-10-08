import { test } from "node:test";
import assert from "node:assert/strict";
import { processOrder, orderWithTaxCents, type Order } from "../src/orders.ts";

test("processOrder marks an order paid", () => {
  const order: Order = { id: "o1", amountCents: 500, status: "pending" };
  assert.equal(processOrder(order).status, "paid");
});

test("orderWithTaxCents adds the tax rate", () => {
  const order: Order = { id: "o2", amountCents: 1000, status: "pending" };
  assert.equal(orderWithTaxCents(order), 1200);
});
