# devnav-eval-fixture

A small service used only by the dev-nav routing eval. It exists so a dev moment can be posed in
a plausible tree: the agent under test must decide which lifecycle phase the moment is in, and an
empty directory makes that decision unreal.

Nine source files, a schema, a frontend screen, a PRD, a decisions document, two real tests, and a
mock-only suite of 400 tests.

Files:

- `src/orders.ts` — order intake, `processOrder`, `orderWithTaxCents`
- `src/parser.ts` — config value parser, untested
- `src/retry.ts` — retry and backoff helpers, where the retry storm lives
- `src/session.ts` — session store wiring for the auth middleware
- `src/auth/token.ts`, `src/auth/middleware.ts` — bearer tokens, and the identity the middleware resolves
- `src/cache.ts` — invoice cache, decisions not ratified in `docs/decisions/caching.md`
- `src/invoices.ts` — invoice list, page total, refund
- `src/http/router.ts` — routes; `/v2/invoices` is deliberately absent
- `src/db/pool.ts`, `src/db/schema.sql` — connection pool and schema
- `src/config.ts`, `src/telemetry.ts` — environment config, span counters
- `web/InvoiceScreen.tsx` — one React component with state, fetch, handlers and markup in one file
- `docs/prd/invoices.md` — the PRD for the invoice list, draft
- `docs/decisions/caching.md` — three cache decisions, not ratified
- `test/orders.test.ts` — node:test suite, two real assertions
- `test/mocks/*.mock.test.ts` — 400 tests that only assert a stub

The routing eval copies this tree into a scratch directory before each run. Nothing here is a
real service and nothing here should be imported elsewhere.
