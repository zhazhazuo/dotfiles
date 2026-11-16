# Hosts

One directory per machine. The directory name is the machine's profile, and a
profile is a label, not always the hostname: this Mac answers `hostname -s` with
`U-JJR9RWLP-0158` and uses the `VCN` profile. The shared configuration holds
values every machine shares. A value two machines must not share lives here.

The installer resolves the profile in three steps. It takes a profile named as
its first argument, so `sh init.sh VCN` works on a fresh machine. Failing that,
it reads the target of the existing `~/.config/fish/conf.d/zz-host.fish` link,
which is how a configured machine records its own profile and keeps it across a
hostname change. Failing that, it uses `hostname -s`.

It then links and merges that directory's files over the shared configuration. A
machine with no directory for its profile cannot finish the install: the shared
files hold no proxy, no Confluence flags and no default model, so the installer
stops and names the path it looked for.

## What belongs in a host directory

- `fish/conf.d/zz-host.fish` — proxy endpoints, tool flags, anything the
  machine must export differently. The `zz-` prefix loads the fragment after
  every shared fragment, so a host value wins.
- `pi-settings.json` — only the pi settings keys that differ per machine,
  today `defaultProvider` and `defaultModel`. The installer merges this over
  the shared `pi/settings.json`; a key here replaces the same key there.
- Credentials never go in either file. `fish/conf.d/env.fish` loads
  `~/.config/secrets/.env`, which holds the tokens and sits outside every
  repository, so no checkout and no `git add -f` can reach it.

## Adding a machine

1. Copy `hosts/M5/` to `hosts/<profile>/` and edit the values.
2. Commit. Both machines now share one branch without conflicts.
3. Run `sh init.sh <profile>`. The run links the profile, so the machine records
   it from then on.
