---
name: api-mock
description: Use when a frontend needs a backend endpoint that does not exist yet, when local development is blocked on an unfinished API, or when a review needs a backend state (empty, error, duplicate, slow) that staging cannot produce.
disable-model-invocation: true
---

# API Mock Server

**Sandbox root:** `~/Work/mock-server` — a Mockoon workspace; this global entry is a symlink to the sandbox copy.

## Purpose

Serve a missing or unavailable endpoint from a per-project Mockoon profile, so the real screen renders while the product repository changes only its proxy target.

## When to Use

- A frontend feature is ahead of its backend and the page must render end to end.
- A review needs a state the backend cannot produce on demand: empty list, 500, duplicate submit, slow response.
- Staging is unreachable, flaky, or cannot be put into the needed state.

**Do not use** for unit or component tests — those mock at the module boundary (`vi.mock('~/utils/api')`) and need no server. Not for e2e suites either: those own their fixtures next to the tests.

## Process

1. Start the profile: `cd ~/Work/mock-server && bun run mock <project>`. Add `--proxy <real-backend>` to forward everything the profile does not declare.
2. Point the project at it — one proxy target, never code (`references/wiring.md`).
3. Verify before touching the UI: `curl` the endpoint and read the envelope, then load the screen, then read the server log (`references/wiring.md`).
4. Author or extend a profile when an endpoint is missing (`references/profiles.md`).
5. Delete the profile and the project's proxy entry in the same task that ships the real endpoint.

## Progressive Disclosure

- Sandbox layout, profiles, routes, fixtures → `references/profiles.md`
- Proxy wiring, verification order, contract cross-check → `references/wiring.md`
- Failure modes and their fixes → `references/pitfalls.md`

## Constraints

- Mock code never enters a product repository.
- A fixture is the body the client receives, envelope included.
- Payloads are copied from real responses, never invented.
- Partial proxy by default; auth and untouched screens keep the real backend.
- Mirror status codes and error bodies; never re-implement backend rules, never mock auth.
- Toggles are per request (`?empty=1`, header rules), not per file edit.
