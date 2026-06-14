# Deploy

## Build Steps

1. No build step detected.
2. Keep `lazy-lock.json` updated when plugin versions intentionally change.

## Deploy Command

- deploy → managed by the surrounding dotfiles workflow

## Pipeline

```mermaid
flowchart LR
  Edit[Edit config] --> Check[Run local checks]
  Check --> Commit[Commit dotfiles]
  Commit --> Sync[Sync target machines]
```

