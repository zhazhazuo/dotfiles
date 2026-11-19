# Cache decisions, settled 2026-11-02

Decisions taken in the invoice caching session. The spec is not written yet.

1. The invoice list is cached for 60 seconds. The invoice detail is not cached.
2. The cache key is `tenant:<id>:invoices:<page>`. Page numbers start at 1.
3. A refund invalidates the tenant's whole invoice list, not one page.

## Still open

- Whether a cache miss on one page warms the other pages.
- Whether the 60 seconds starts at the write or at the read.

The human has not ratified items 1 to 3. Nothing in `src/cache.ts` should be treated as final
until they do.
