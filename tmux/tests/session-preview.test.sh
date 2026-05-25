#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/session-preview.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

case "$1" in
list-windows)
	printf '0\tmain\n'
	printf '1\tlogs\n'
	printf '2\ttest\n'
	printf '3\tshell\n'
	;;
capture-pane)
	target=""
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-t)
			target="$2"
			shift 2
			;;
		*)
			shift
			;;
		esac
	done
	printf '%s line 1\n' "$target"
	printf '%s line 2\n' "$target"
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

PATH="$TMP_DIR:$PATH"

actual="$("$SCRIPT" alpha)"
if [[ -n "$actual" ]]; then
	printf 'not ok - session target renders no preview\n' >&2
	printf '%s\n' "$actual" >&2
	exit 1
fi
printf 'ok - session target renders no preview\n'

actual="$("$SCRIPT" alpha:1)"
expected=$'alpha:1 line 1\nalpha:1 line 2'
if [[ "$actual" != "$expected" ]]; then
	printf 'not ok - window target previews full capture directly\n' >&2
	printf 'expected:\n%s\n' "$expected" >&2
	printf 'actual:\n%s\n' "$actual" >&2
	exit 1
fi
printf 'ok - window target previews full capture directly\n'
