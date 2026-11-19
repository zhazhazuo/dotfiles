-- Schema for the invoice service, eval fixture only.
CREATE TABLE tenants (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE invoices (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL REFERENCES tenants(id),
  amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0),
  status TEXT NOT NULL CHECK (status IN ('pending', 'paid', 'refunded')),
  issued_at TEXT NOT NULL
);

CREATE INDEX invoices_tenant_issued ON invoices (tenant_id, issued_at DESC);
