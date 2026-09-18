# Wiring and verification

## Two ways to point a project at the mock server

| | Project change | Mock server needs |
|---|---|---|
| **Namespace proxy** (default) | one entry before the catch-all: `'/api/cdc': { target: 'http://localhost:4111' }` | nothing — only the declared routes matter |
| **Full swap** | `.env`: `PROXY_DOMAIN=http://localhost:4111` | `--proxy <real-backend>`, or every unmocked screen breaks |

Namespace proxy is the default because auth, menu and every untouched screen keep their real backend. Full swap is for when the backend is down entirely.

```ts
// nuxt.config.ts / vite.config.ts — order matters: the specific entry must come first
proxy: {
  '/api/cdc': { target: 'http://localhost:4111', changeOrigin: true },
  '/api': { target: PROXY_DOMAIN, changeOrigin: true },
}
```

Any dev server that can proxy a path prefix works the same way: send the mocked prefix to the profile's port, leave the rest alone. If a project has no proxy at all, use the full swap and start the profile with `--proxy`.

## Verification order

Run these three in order; each one catches a different class of mistake.

1. **The endpoint** — status *and* envelope, before any UI work:

   ```bash
   curl -s "http://localhost:4111/api/cdc/forms" | head -c 200
   # {"code":200,"data":{"forms":[{"formId":"epage-briefing",…}]},"msg":null,"success":true}
   ```

   A payload without its envelope reads as `data: null` in the client and shows up as a broken screen.

2. **The screen** — load the route and confirm the state you mocked appears. If it does not, the request never reached the profile: check the proxy entry order (the namespace entry must come before the catch-all).

3. **The server log** — every call is logged with method, path, status and whether it was proxied:

   ```json
   {"message":"Transaction recorded","requestMethod":"GET","requestPath":"/api/cdc/forms","requestProxied":false,"responseStatus":200}
   ```

   `requestProxied: true` means the profile did not declare that path. The log is also how you discover the endpoints a screen needs but nobody mocked yet — click through the feature and watch it.

## Contract cross-check (optional)

When the API has an OpenAPI document (CDC does — Confluence "Tech Doc: CDC"), Prism proves the frontend matches the published contract:

```bash
npx @stoplight/prism-cli mock spec.yaml           # serve the spec directly
npx @stoplight/prism-cli proxy spec.yaml http://localhost:4111   # validate traffic against it
```

Use it as a second opinion on payload shape. It cannot replace a profile: Prism has no route-declared-plus-upstream behaviour, so nothing is forwarded to the real backend.
