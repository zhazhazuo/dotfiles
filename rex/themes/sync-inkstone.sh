#!/bin/sh
# Regenerate Rex terminal themes from the Inkstone repository.
#
# Inkstone owns the colors: its palette files define the ANSI slots, the
# contrast audit and the chroma budget. This script does not guess any color.
# It clones the repository once, then asks its own Ghostty generator for a
# flavor and writes the result into this directory.
#
# Usage:
#   sync-inkstone.sh                      # xuanmo-dimmed only
#   sync-inkstone.sh xuanmo xuanzhi       # any flavor ids
#   INKSTONE_REPO=~/src/inkstone sync-inkstone.sh
#
# Then install and select a theme:
#   rex do client.theme.import path="$HOME/.config/rex/themes/Inkstone Xuanmo Dimmed"

set -eu

out_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=${INKSTONE_REPO:-$HOME/.cache/inkstone}
flavors=${*:-xuanmo-dimmed}

if [ ! -d "$repo/.git" ]; then
  mkdir -p "$(dirname -- "$repo")"
  git clone --depth 1 https://github.com/Konata9/inkstone "$repo" >&2
else
  git -C "$repo" pull --ff-only --depth 1 >&2
fi

cat > "$repo/rex-theme-gen.ts" <<'TS'
import { writeFileSync } from 'node:fs';
import { flavors, flavorName } from './src/palette/index.ts';
import { buildGhosttyTheme } from './src/targets/ghostty.ts';

const [want, outDir] = process.argv.slice(2);
const flavor = flavors.find((f) => f.meta.id === want);
if (!flavor) {
  const known = flavors.map((f) => f.meta.id).join(', ');
  throw new Error(`unknown flavor "${want}"; known: ${known}`);
}
const name = `Inkstone ${flavorName(flavor, 'en')}`;
const path = `${outDir}/${name}`;
writeFileSync(path, buildGhosttyTheme(flavor));
console.log(path);
TS

cd "$repo"
for flavor in $flavors; do
  bun ./rex-theme-gen.ts "$flavor" "$out_dir"
done
