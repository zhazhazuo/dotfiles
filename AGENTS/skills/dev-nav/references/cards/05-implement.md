# 05 Implement

Phase gate: you cannot leave phase 5 without the artifact below.
Skills, by condition: `write-discoverable-code` always; `structuring-ui-components` only when the
target is a React or Vue component; `api-mock` only when the endpoint does not exist yet. Read
every skill whose condition matches, and only those.

- `~/.agents/skills/write-discoverable-code/SKILL.md`
- `~/.agents/skills/structuring-ui-components/SKILL.md`
- `~/.agents/skills/api-mock/SKILL.md`

## Enter

- A failing test exists (phase 4), or the change is not test-coverable.

## Exit artifact

Code that passes the phase 4 test, with names one search resolves; components whose logic sits
outside markup; and, where an endpoint was missing, a local profile that is deleted in the same
task that ships the real endpoint.

## Earns its place

**`write-discoverable-code`** — prevents an export one search cannot find.
Measured: on a ~700k-line monorepo, 1-word exported names are globally unique 61% of the time,
3-word names 96%, 4+ words 98%. Three words is the knee. Every identifier is a search query and
every search miss costs wasted reads.

**`structuring-ui-components`** — prevents render markup tangled with state, handlers, validation,
or async logic. Applies Functional Core / Imperative Shell / Render Shell. It excludes
presentational-only components with no state or logic: a single file is correct there, so this
card does not fire on them. Evidence: unmeasured; the failure is a component that cannot be
tested without rendering it.

**`api-mock`** — prevents local development and review stalling on an endpoint that does not exist,
or a backend state (empty, 500, duplicate, slow) staging cannot produce. Constraint that keeps it
honest: mock code never enters a product repository, payloads are copied from real responses and
never invented, and the profile is deleted in the same task that ships the real endpoint.

## Not this card

- Visual design, prototypes, and shadcn route to `design-nav`.
- A component with no state or logic needs no restructuring.
- Unit and component tests mock at the module boundary and need no server; E2E owns its fixtures
  next to the tests. The mock server is for neither.

## Handoff

Phase 8 consumes the passing test. Phase 6 is entered from here whenever this phase produces an
unexplained failure.
