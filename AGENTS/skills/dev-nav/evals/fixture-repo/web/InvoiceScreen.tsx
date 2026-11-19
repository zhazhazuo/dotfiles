// Invoice screen. Fetches /v2/invoices, which does not exist yet.
import { useEffect, useState } from "react";

type Invoice = {
  id: string;
  amountCents: number;
  status: "pending" | "paid" | "refunded";
};

export function InvoiceScreen({ tenantId }: { tenantId: string }) {
  const [page, setPage] = useState(1);
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetch(`/v2/invoices?tenant=${tenantId}&page=${page}`)
      .then((response) => {
        if (!response.ok) throw new Error(`invoices failed: ${response.status}`);
        return response.json();
      })
      .then((body: { invoices: Invoice[] }) => {
        if (alive) setInvoices(body.invoices);
      })
      .catch((cause: Error) => {
        if (alive) setError(cause.message);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [tenantId, page]);

  const total = invoices
    .filter((invoice) => invoice.status !== "refunded")
    .reduce((sum, invoice) => sum + invoice.amountCents, 0);

  function onRefund(id: string) {
    setSelected(id);
    fetch(`/v1/invoices/${tenantId}/${id}/refund`, { method: "POST" }).then(() => {
      setInvoices((current) =>
        current.map((invoice) => (invoice.id === id ? { ...invoice, status: "refunded" } : invoice))
      );
    });
  }

  if (loading) return <p>Loading invoices</p>;
  if (error) return <p role="alert">{error}</p>;
  if (!invoices.length) return <p>No invoices yet</p>;

  return (
    <section>
      <header>
        <h2>Invoices</h2>
        <p>Page total: {(total / 100).toFixed(2)}</p>
      </header>
      <ul>
        {invoices.map((invoice) => (
          <li key={invoice.id} data-selected={selected === invoice.id}>
            <span>{invoice.id}</span>
            <span>{(invoice.amountCents / 100).toFixed(2)}</span>
            <span>{invoice.status}</span>
            {invoice.status === "paid" ? (
              <button type="button" onClick={() => onRefund(invoice.id)}>Refund</button>
            ) : null}
          </li>
        ))}
      </ul>
      <nav>
        <button type="button" onClick={() => setPage((current) => Math.max(1, current - 1))}>
          Previous
        </button>
        <button type="button" onClick={() => setPage((current) => current + 1)}>
          Next
        </button>
      </nav>
    </section>
  );
}
