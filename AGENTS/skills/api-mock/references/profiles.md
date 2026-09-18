# Profiles

```text
~/Work/mock-server/
├── bin/mock.ts                        # list | start | --proxy <url> | --port <n>
├── scripts/wrap-fixtures.ts           # raw payload + project envelope → served body
└── projects/<project>/
    ├── environment.json               # one Mockoon environment: port, routes, responses
    └── fixtures/
        ├── manifest.json              # raw → served mapping
        ├── source/*.json              # raw payloads (captured or copied from the repo)
        └── <namespace>/*.json         # generated bodies, grouped by API area — never edit by hand
```

`projects/sales-tool/` is the reference implementation; copy it when starting a profile.

## Commands

```bash
bun run mock                     # list profiles with their routes
bun run mock sales-tool          # start one
bun run mock sales-tool --proxy http://staging.internal:8080   # + forward the rest
bun run mock sales-tool --port 4200
bun run fixtures                 # regenerate served bodies from fixtures/source
```

## Environment file

Only these fields carry meaning for this sandbox; everything else is Mockoon defaults:

- `name`, `port` — identity and where it listens. Ports are 41xx, one per project, so profiles run side by side.
- `latency` — milliseconds added to every response. 200 keeps loading states visible in review.
- `routes[]` — `method`, `endpoint` (the **full** path, e.g. `api/cdc/forms`), and one response per state.
- `responses[]` — `statusCode`, `bodyType`, `filePath` for `FILE`, `body` for `INLINE`, `sendFileAsBody: true` to return that file verbatim, plus `rules` that select the response.
- `proxyMode` / `proxyHost` — set by `--proxy` at start, so the committed file stays upstream-free.

`bodyType` choice: `FILE` for any real payload; `INLINE` only for a small body that needs templating.

## Add an endpoint

1. Raw payload → `projects/<project>/fixtures/source/<name>.json`.
2. Describe it in `fixtures/manifest.json`: `{ "input", "output", "wrap": "config" | "catalog" | "raw" }`.
3. `bun run fixtures` — writes the enveloped body into `fixtures/`.
4. Add the route to `environment.json`, one response per state.
5. Restart the profile and follow the verification order in `wiring.md`.

Example route with two states — the second is selected by a request rule, so no restart is needed to switch:

```jsonc
{
  "method": "get",
  "endpoint": "api/cdc/forms",
  "responses": [
    { "statusCode": 200, "label": "empty", "bodyType": "INLINE",
      "body": "{\"code\":200,\"data\":{\"forms\":[]},\"msg\":null,\"success\":true}",
      "rules": [{ "target": "query", "modifier": "empty", "value": "1", "operator": "equals" }] },
    { "statusCode": 200, "label": "default", "bodyType": "FILE",
      "filePath": "fixtures/cdc/forms.json", "sendFileAsBody": true, "default": true }
  ]
}
```

Rule targets used so far: `query`, `header`. Operators: `equals`, `regex` (with `invert` for "not this value").

## Add a project profile

1. Copy `projects/sales-tool/` to `projects/<project>/`.
2. Set `name` and `port` in `environment.json`; drop the routes that do not apply.
3. Add the project's response envelope to `ENVELOPES` in `scripts/wrap-fixtures.ts` — it is what the project's HTTP client unwraps.
4. Replace the fixtures: payloads into `fixtures/source/`, entries in `fixtures/manifest.json`, then `bun run fixtures`.
5. Wire the project per `wiring.md`.

## Toggles

Toggles used by the current profile — add one when a state must be shown repeatedly, rather than editing the profile between reviews:

| Toggle | Reaches |
|---|---|
| `?empty=1` | empty catalog |
| header `x-mock-duplicate: 1` | 409 duplicate on submit |
| `--proxy <url>` at start | everything the profile does not declare |
