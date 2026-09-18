# Failure modes

Symptom → cause → fix.

| Symptom | Cause | Fix |
|---|---|---|
| Screen shows an error while `curl` looks fine | client reads `resData.data`; body had no envelope | raw payload into `fixtures/source/`, then `bun run fixtures` |
| Mockoon logs a JSON parse error on a body | `{{file 'x.json'}}` inside a JSON body — Mockoon parses JSON before templating | payloads are `bodyType: FILE`; templating only inside string values, e.g. `"formId": "{{queryParam 'formId'}}"` |
| Nothing is mocked, everything hits the real backend | namespace proxy entry placed after the catch-all; Vite matches in order | put `'/api/cdc'` before `'/api'` |
| Every other screen 500s after wiring | full swap without `--proxy`, so unmocked paths 404 | start with `--proxy <real-backend>` or use the namespace proxy |
| Response arrives instantly, loading states never appear | environment `latency` is 0 | set `latency: 200` |
| Review needs a restart to switch state | state encoded by editing the file | one response per state, selected by a request rule |
| Frontend passes locally, fails against staging | mock shape drifted from the real contract | copy payloads from a capture or the project's compiled fixture; cross-check with Prism |
| Mock keeps answering after the backend ships | profile and proxy entry outlived the endpoint | delete both in the task that ships the endpoint |
| Anything about auth or sessions | mocked auth hides a real integration problem | chain to the real backend with `--proxy` |

## Why the two hard rules exist

**Envelope.** Every project wraps responses and unwraps `data`. A bare payload is not a "simpler mock" — it produces an error state identical to a real bug, and the next hour goes into debugging the frontend.

**Proxy order.** With the namespace entry after the catch-all, the mock server is never called. The failure is silent: the app works exactly as it did before, which reads as "the profile does nothing".
