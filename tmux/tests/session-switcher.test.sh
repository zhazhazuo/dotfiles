#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/session-switcher.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat >"$TMP_DIR/tmux" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >>"$TMUX_CALL_LOG"

case "$1" in
list-windows)
	printf '300\talpha\t0\tmain\t1\t0\n'
	printf '300\talpha\t1\tlogs\t0\t1\n'
	printf '200\tbeta\t0\tserver\t1\t0\n'
	;;
switch-client)
	printf '%s\n' "$3" >"$TMUX_SWITCH_TARGET"
	;;
*)
	exit 1
	;;
esac
FAKE_TMUX
chmod +x "$TMP_DIR/tmux"

cat >"$TMP_DIR/fzf" <<'FAKE_FZF'
#!/usr/bin/env bash

set -euo pipefail

printf '%s\n' "$*" >"$FZF_ARGS_LOG"
cat >"$FZF_INPUT_LOG"
printf '%s\n' "${FZF_SELECTION:-alpha:1	logs}"
FAKE_FZF
chmod +x "$TMP_DIR/fzf"

PATH="$TMP_DIR:$PATH"
export TMUX_CALL_LOG="$TMP_DIR/tmux.calls"
export TMUX_SWITCH_TARGET="$TMP_DIR/target"
export FZF_INPUT_LOG="$TMP_DIR/fzf.input"
export FZF_ARGS_LOG="$TMP_DIR/fzf.args"

"$SCRIPT"

expected_calls=$'list-windows -a -F #{session_last_attached}\t#{session_name}\t#{window_index}\t#{window_name}\t#{window_active}\t#{window_last_flag}\nswitch-client -t alpha:1'
actual_calls="$(cat "$TMUX_CALL_LOG")"
if [[ "$actual_calls" != "$expected_calls" ]]; then
	printf 'not ok - uses only list-windows and switch-client\n' >&2
	printf 'expected:\n%s\n' "$expected_calls" >&2
	printf 'actual:\n%s\n' "$actual_calls" >&2
	exit 1
fi
printf 'ok - uses only list-windows and switch-client\n'

target="$(cat "$TMUX_SWITCH_TARGET")"
if [[ "$target" != "alpha:1" ]]; then
	printf 'not ok - switches to selected window target\n' >&2
	printf 'expected: alpha:1\n' >&2
	printf 'actual:   %s\n' "$target" >&2
	exit 1
fi
printf 'ok - switches to selected window target\n'

fzf_input="$(cat "$FZF_INPUT_LOG")"
expected_fzf_input=$'alpha\t\033[38;2;110;115;141malpha\033[0m\nalpha:0\t  \033[38;2;166;218;149m\033[0m main \033[38;2;110;115;141m· alpha\033[0m\nalpha:1\t    logs \033[38;2;110;115;141m· alpha\033[0m\nbeta\t\033[38;2;110;115;141mbeta\033[0m\nbeta:0\t  \033[38;2;166;218;149m\033[0m server \033[38;2;110;115;141m· beta\033[0m'
if [[ "$fzf_input" != "$expected_fzf_input" ]]; then
	printf 'not ok - shows session tree with window names in fzf\n' >&2
	printf 'expected:\n%s\n' "$expected_fzf_input" >&2
	printf 'actual:\n%s\n' "$fzf_input" >&2
	exit 1
fi
printf 'ok - shows session tree with window names in fzf\n'

if [[ "$fzf_input" == *$'\n\n'* ]]; then
	printf 'not ok - omits blank current-session row before fzf\n' >&2
	exit 1
fi
printf 'ok - omits blank current-session row before fzf\n'

"$SCRIPT" --popup

fzf_args="$(cat "$FZF_ARGS_LOG")"
if [[ "$fzf_args" != "--reverse --exit-0 --ansi --delimiter=	 --with-nth=2.. --accept-nth=1 --bind=enter:accept-non-empty --layout=reverse --style=minimal --border=none --list-border=none --input-border=none --header-border=none --padding=1,3 --no-separator --info=inline-right --header=  --prompt=  Sessions   --pointer=▌ --marker=• --border-label= tmux session switcher  --border-label-pos=3 --color=fg:#cad3f5,bg:-1,fg+:#f4dbd6,bg+:-1,hl:#8aadf4,hl+:#f5bde6,info:#6e738d,prompt:#8aadf4,pointer:#f5bde6,marker:#a6da95,spinner:#f5bde6,header:#6e738d,border:#6e738d,gutter:-1,label:#6e738d --tmux=center,48,11,border-native" ]]; then
	printf 'not ok - popup mode adapts size and padding to the list\n' >&2
	printf 'expected popup args with content-aware geometry\n' >&2
	printf 'actual:   %s\n' "$fzf_args" >&2
	exit 1
fi
printf 'ok - popup mode adapts size and padding to the list\n'

rm -f "$TMUX_CALL_LOG"
FZF_SELECTION=$'alpha\talpha' "$SCRIPT"

expected_calls=$'list-windows -a -F #{session_last_attached}\t#{session_name}\t#{window_index}\t#{window_name}\t#{window_active}\t#{window_last_flag}\nswitch-client -t alpha'
actual_calls="$(cat "$TMUX_CALL_LOG")"
if [[ "$actual_calls" != "$expected_calls" ]]; then
	printf 'not ok - switches to selected session target\n' >&2
	printf 'expected:\n%s\n' "$expected_calls" >&2
	printf 'actual:\n%s\n' "$actual_calls" >&2
	exit 1
fi
printf 'ok - switches to selected session target\n'
