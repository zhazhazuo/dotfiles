# devnav-eval-fixture

A three-file service used only by the dev-nav routing eval. It exists so a dev moment can be
posed in a plausible tree: the agent under test must decide which lifecycle phase the moment is
in, and an empty directory makes that decision unreal.

Files:

- `src/orders.ts` — order intake, `processOrder`, `orderWithTaxCents`
- `src/session.ts` — session store wiring for the auth middleware
- `src/retry.ts` — retry and backoff helpers, where the retry storm lives
- `test/orders.test.ts` — node:test suite

The routing eval copies this tree into a scratch directory before each run. Nothing here is a
real service and nothing here should be imported elsewhere.
