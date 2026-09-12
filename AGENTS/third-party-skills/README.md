# Third-party agent skills

```text
Purpose : canonical store for `npx skills` third-party installs
Symlink : ~/.config/agents/skills -> this directory
Custom  : ~/dotfiles/AGENTS/skills/ (hand-written skills, kept separate)
```

This directory is the canonical store for skills installed by `npx skills`.
The path `~/.config/agents/skills` is a symlink to this directory. The
`universal` target of `npx skills` writes real files here, so every
third-party skill is version-controlled in dotfiles.

Custom (hand-written) skills live in `~/dotfiles/AGENTS/skills/`. Do not mix
the two. The `init.sh` script symlinks both into `~/.agents/skills/`.

## Install a third-party skill

```text
Step 1: add the package to skills.txt (one owner/repo per line)
Step 2: run ~/dotfiles/init.sh, or install by hand:
        npx -y skills add <owner/repo> -g -a universal --skill '*' -y
Step 3: run the integrate-capability flow for each new skill
```

Add the package to `skills.txt`. Run `~/dotfiles/init.sh`, or install by hand.

## Update third-party skills

```bash
npx -y skills update -g -y
```

Warning: `npx skills update` rewrites skill files. Frontmatter edits revert
on update. Re-apply the silencing patch after every update.

## Integrate a new skill (per skill)

Follow the integrate-capability flow in `~/dotfiles/AGENTS/skills/integrate-capability/`.
For each new skill:

1. Silence the skill if it must not auto-trigger. Add
   `disable-model-invocation: true` to the frontmatter of its `SKILL.md`.
2. Add a row for the skill to `~/dotfiles/AGENTS/AGENTS.md` so the router
   can point at it.
3. Run `~/dotfiles/init.sh` again, or symlink it by hand, if a new skill
   directory must appear in `~/.agents/skills/`.

## Remove a third-party skill

```bash
npx -y skills remove -g
```

Then delete the entry from `skills.txt` and the AGENTS.md row.
