# Hosts

One directory per machine, named after the machine's `hostname -s` output
(`M5`, `VCN`). The shared configuration holds values every machine
shares. A value two machines must not share lives here.

The installer reads `hostname -s`, then links and merges this directory's
files over the shared configuration. A machine with no directory here loads
the shared configuration alone, which is the safe default.

## What belongs in a host directory

- `fish/conf.d/zz-host.fish` — proxy endpoints, tool flags, anything the
  machine must export differently. The `zz-` prefix loads the fragment after
  every shared fragment, so a host value wins.
- `pi-settings.json` — only the pi settings keys that differ per machine,
  today `defaultProvider` and `defaultModel`. The installer merges this over
  the shared `pi/settings.json`; a key here replaces the same key there.
- Credentials never go in either file. `fish/conf.d/env.fish` loads the
  gitignored `~/.config/fish/.env`, which holds the tokens.

## Adding a machine

1. Run `hostname -s` on the machine.
2. Copy `hosts/M5/` to `hosts/<that-name>/` and edit the values.
3. Commit. Both machines now share one branch without conflicts.
