# PRD: invoice list for tenants

Status: draft. Owner: finance platform. Nothing in this document is implemented.

## R1 List

A tenant sees its own invoices, newest first, 25 per page.

## R2 Total

Each row shows the invoice total in minor units, with tax applied once. Tax is 20 per cent.

## R3 Status

An invoice is `pending`, `paid`, or `refunded`. A refunded invoice stays in the list with a
`refunded` label and its total is not counted in the page total.

## R4 Empty state

A tenant with no invoices sees "No invoices yet" and the page total reads 0.

## Edge cases

- A page number past the last page returns an empty list, not an error.
- An invoice with `amountCents` of 0 is valid and renders as `0.00`.
- A tenant id that does not exist returns an empty list, never another tenant's invoices.

## Out of scope

- Creating or editing invoices.
- Exporting.
- The `/v2/invoices` endpoint. It does not exist yet; the screen is built against a local mock.
