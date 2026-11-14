#!/usr/bin/env bash
#
# apply.test.sh — the already-applied check in pi/patches/apply.sh
#
# The failure this test pins: Apple's /usr/bin/patch answers its own
# "Unreversed (or previously applied) patch detected!" prompt with yes, so a
# reverse dry-run exits 0 on a file the patch has NOT touched, and apply.sh
# reported "already applied" while the report was missing. The account sat in
# that state on 2025-11-14.
#
# The check must therefore judge by content, not by exit status: forward-apply
# the patch to a copy of the file and compare.
#
#   sh pi/patches/apply.test.sh
#
# Exit status 0 means every case passed.

set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APPLY="$ROOT_DIR/apply.sh"
PATCH_FILE="$ROOT_DIR/rpiv-ask-user-question-blocked.patch"
PACKAGE="@juicesharp/rpiv-ask-user-question"
MARKER="blockedOnQuestion"
INSTALLED="$HOME/.pi/agent/npm/node_modules/$PACKAGE/ask-user-question.ts"

WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT INT TERM

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
nope() { FAIL=$((FAIL + 1)); printf 'FAIL %s: %s\n' "$1" "$2"; }

# The fixture needs a real file the patch applies to. Derive both states from
# the installed file: reverse-apply a copy to get the unpatched original; the
# installed file itself, or a forward-applied copy, is the patched state.
make_variants() {
  local dir="$WORK/packages/$PACKAGE"
  mkdir -p "$dir"
  cp "$INSTALLED" "$dir/ask-user-question.ts"
  if (cd "$dir" && patch -p1 -R -s -i "$PATCH_FILE" </dev/null >/dev/null 2>&1) \
    && ! cmp -s "$INSTALLED" "$dir/ask-user-question.ts"; then
    cp "$dir/ask-user-question.ts" "$WORK/unpatched.ts"
    cp "$INSTALLED" "$WORK/patched.ts"
  else
    cp "$INSTALLED" "$WORK/patched.ts"
    cp "$INSTALLED" "$dir/ask-user-question.ts"
    if (cd "$dir" && patch -p1 -s -i "$PATCH_FILE" </dev/null >/dev/null 2>&1) \
      && ! cmp -s "$INSTALLED" "$dir/ask-user-question.ts"; then
      cp "$dir/ask-user-question.ts" "$WORK/unpatched.ts"
    else
      printf 'FAIL fixture: cannot derive an unpatched variant\n' >&2
      exit 1
    fi
  fi
}

install_variant() { # unpatched|patched
  local dir="$WORK/packages/$PACKAGE"
  mkdir -p "$dir"
  cp "$WORK/$1.ts" "$dir/ask-user-question.ts"
}

run_apply() {
  PI_NODE_MODULES_DIR="$WORK/packages" bash "$APPLY" 2>&1
}

marker_count() {
  grep -c "$MARKER" "$WORK/packages/$PACKAGE/ask-user-question.ts" || true
}

make_variants

# Case 1: an unpatched package gets the patch and the marker line.
install_variant unpatched
OUT=$(run_apply)
if [[ "$OUT" == *"applied to"* ]]; then
  ok "unpatched package is patched"
else
  nope "unpatched package is patched" "output was: $OUT"
fi
if [[ "$(marker_count)" -ge 1 ]]; then
  ok "unpatched package carries the marker after apply"
else
  nope "unpatched package carries the marker after apply" "marker count: $(marker_count)"
fi

# Case 2: a patched package is left alone and reported as already applied.
install_variant patched
OUT=$(run_apply)
if [[ "$OUT" == *"already applied"* ]]; then
  ok "patched package is reported as already applied"
else
  nope "patched package is reported as already applied" "output was: $OUT"
fi
if [[ "$(marker_count)" -ge 1 ]]; then
  ok "patched package is unchanged"
else
  nope "patched package is unchanged" "marker count: $(marker_count)"
fi

# Case 3: a second run over a just-patched package changes nothing.
install_variant unpatched
run_apply > /dev/null
OUT=$(run_apply)
if [[ "$OUT" == *"already applied"* ]]; then
  ok "a second run is idempotent"
else
  nope "a second run is idempotent" "output was: $OUT"
fi

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
