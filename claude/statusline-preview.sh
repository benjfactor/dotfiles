#!/usr/bin/env bash
# Show the status-line bars at every level.
#
#   statusline-preview.sh              stacked sweep, 0-100 in steps of 2
#   statusline-preview.sh -s 1         every single percent
#   statusline-preview.sh states       just the states where something changes
#   statusline-preview.sh -f OTHER.sh  preview a different copy of the script
#
# The bar/colour functions are lifted out of statusline-command.sh at run time
# rather than copied, so this cannot drift from what the bar actually draws.

set -uo pipefail
MODE=sweep STEP=2 SL="$HOME/.claude/statusline-command.sh"
while [ $# -gt 0 ]; do
    case "$1" in
        sweep|states) MODE=$1; shift ;;
        -s|--step)    STEP=${2:-2}; shift 2 ;;
        -f|--file)    SL=${2:?}; shift 2 ;;
        -h|--help)    sed -n '2,9p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)            echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done
[ -r "$SL" ] || { echo "cannot read $SL" >&2; exit 1; }

eval "$(sed -n '/^make_bar5()/,/^}/p; /^make_bar10()/,/^}/p; /^pct_badge()/,/^}/p; /^rate_color()/,/^}/p; /^context_color()/,/^}/p' "$SL")"
for fn in make_bar5 make_bar10 rate_color context_color; do
    declare -F "$fn" >/dev/null || { echo "missing $fn in $SL" >&2; exit 1; }
done
declare -F pct_badge >/dev/null || pct_badge() { :; }

R=$'\e[0m'; DIM=$'\e[38;2;76;76;76m'
cname() { case "$1" in *'[0;31m') echo red ;; *'[0;33m') echo yellow ;; *'[0;32m') echo green ;; *) echo "?" ;; esac; }

printf '\n   %-6s %-13s %s\n' "pct" "rate limit" "context"
printf '  %s\n' "$(printf '─%.0s' $(seq 1 52))"

pb="" pc="" cc=""
for p in $(seq 0 "$STEP" 100); do
    b5=$(make_bar5 "$p");  c5=$(rate_color "$p");    bd=$(pct_badge "$p")
    b10=$(make_bar10 "$p"); c10=$(context_color "$p")

    marks=()
    [ -n "$pb" ] && [ "$b5"  != "$pb" ] && marks+=("bar")
    [ -n "$pc" ] && [ "$c5"  != "$pc" ] && marks+=("$(cname "$c5")")
    [ -n "$cc" ] && [ "$c10" != "$cc" ] && marks+=("ctx $(cname "$c10")")
    [ "$p" = 90 ] && marks+=("pct on"); [ "$p" = 100 ] && marks+=("pct off")

    if [ "$MODE" = states ] && [ ${#marks[@]} -eq 0 ] && [ "$p" != 0 ]; then
        pb=$b5 pc=$c5 cc=$c10; continue
    fi
    note=""; [ ${#marks[@]} -gt 0 ] && note="${DIM}<- $(IFS=,; echo "${marks[*]}")${R}"
    printf '  %4d   %b%-5s%b%-5s %b%-10s%b  %b\n' \
        "$p" "$c5" "$b5" "$R" "${bd:- }" "$c10" "$b10" "$R" "$note"
    pb=$b5 pc=$c5 cc=$c10
done
printf '\n'
