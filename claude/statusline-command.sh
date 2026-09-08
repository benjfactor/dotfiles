#!/usr/bin/env bash

input=$(cat)

# --- Calibration mode ---------------------------------------------------------
# The harness reports COLUMNS but draws the bar in less room than that, and
# nothing in its JSON says how much less. `touch ~/.cache/claude-statusline/RULER`
# swaps the bar for a column ruler so the real drawable width can be read off
# the screen; delete the file to restore normal output.
if [ -f "$HOME/.cache/claude-statusline/RULER" ]; then
    python3 - <<'PYRULER'
import os
w = int(os.environ.get("COLUMNS", "80"))
E = chr(27)
G1 = E + "[38;2;153;153;153m"
G2 = E + "[38;2;76;76;76m"
GR = E + "[0;32m"
ON = E + "[22m"
OFF = E + "[0m"

# Reproduce the real bar's escape density (15 sequences on line 1) so the
# over-count being measured is the one that actually bites.
for m in (0, 2, 4, 6, 8, 10, 14, 20):
    label = "M%d-END" % m
    vis = w - m
    body = "." * (vis - len(label))
    # sprinkle 15 colour changes through the filler
    step = max(1, len(body) // 13)
    out, seqs = [], [G1, G2, GR, G1, G2, GR, G1, G2, GR, G1, G2, GR, G1]
    for i, ch in enumerate(body):
        if i % step == 0 and seqs:
            out.append(seqs.pop(0))
        out.append(ch)
    print(ON + G1 + "".join(out) + G1 + label + OFF)
PYRULER
    exit 0
fi


# --- Status bar greys: explicit, so they no longer follow the theme's `inactive` ---
# Claude Code wraps status line output in ANSI faint (SGR 2) and sets no colour,
# so unstyled text inherits the theme and every faint run is that same colour
# faint-ed twice. \e[22m ("normal intensity") cancels that blanket faint, and the
# two explicit greys below then hold regardless of how dark `inactive` gets.
SB_ON='\e[22m'                  # cancel Claude Code's blanket dim
G1='\e[38;2;153;153;153m'       # shade 1 - the brighter grey you liked at 153
G2='\e[38;2;76;76;76m'         # shade 2 - matches the original faint(153) at ~74
SB_OFF='\e[0m'

# --- Sun glyphs: Nerd Font weather icons (U+E34C rise / U+E34D set) ---
# iTerm2 here renders non-ASCII from FiraMonoNF-Regular, which carries these;
# the ASCII font (DejaVuSansMonoPowerline) does not. Emoji are deliberately
# avoided: they render double-width and force their own colour, which breaks
# both the column alignment and the grey scheme above.
SUN_RISE=''
SUN_SET=''

# --- Model (used on bottom line) ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Session timer ---
session_id=$(echo "$input" | jq -r '.session_id // empty')
timer_str=""
if [ -n "$session_id" ]; then
    timer_file="/tmp/claude-session-${session_id}"
    if [ ! -f "$timer_file" ]; then
        date +%s > "$timer_file"
    fi
    start_time=$(cat "$timer_file")
    now=$(date +%s)
    elapsed=$(( now - start_time ))
    if [ "$elapsed" -ge 3600 ]; then
        timer_str=" · $(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
    else
        timer_str=" · $(( elapsed / 60 ))m"
    fi
fi

# --- Token formatting: 45321 -> 45k, 1000000 -> 1M, 1500000 -> 1.5M ---
fmt_k() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then
        local m_whole=$(( n / 1000000 ))
        local m_dec=$(( (n % 1000000) / 100000 ))
        if [ "$m_dec" -eq 0 ]; then
            printf "%dM" "$m_whole"
        else
            printf "%d.%dM" "$m_whole" "$m_dec"
        fi
    elif [ "$n" -ge 1000 ]; then
        printf "%dk" "$(( n / 1000 ))"
    else
        printf "%s" "$n"
    fi
}

# --- Context window ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
input_tokens=$(echo "$input" | jq -r '
  .context_window.current_usage |
  if . == null then empty
  else ((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))
  end')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

make_bar10() {
    local pct=$1 bar="" i
    local filled=$(( pct * 10 / 100 )) empty=$(( 10 - pct * 10 / 100 ))
    for (( i = 0; i < filled; i++ )); do bar="${bar}█"; done
    for (( i = 0; i < empty;  i++ )); do bar="${bar}░"; done
    echo "$bar"
}

make_bar5() {
    local pct=$1 bar="" i
    local filled=$(( pct * 5 / 100 )) empty=$(( 5 - pct * 5 / 100 ))
    for (( i = 0; i < filled; i++ )); do bar="${bar}█"; done
    for (( i = 0; i < empty;  i++ )); do bar="${bar}░"; done
    echo "$bar"
}

rate_color() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then printf "\e[0;31m"
    elif [ "$pct" -ge 50 ]; then printf "\e[0;33m"
    else printf "\e[0;32m"
    fi
}

fmt_reset() {
    local resets_at=$1
    local now; now=$(date +%s)
    local diff=$(( resets_at - now ))
    if [ "$diff" -le 0 ]; then
        echo "now"
    elif [ "$diff" -lt 3600 ]; then
        echo "$(( diff / 60 ))m"
    elif [ "$diff" -lt 86400 ]; then
        printf "%dh%dm" "$(( diff / 3600 ))" "$(( (diff % 3600) / 60 ))"
    else
        local d=$(( diff / 86400 )) h=$(( (diff % 86400) / 3600 ))
        [ "$h" -gt 0 ] && printf "%dd%dh" "$d" "$h" || printf "%dd" "$d"
    fi
}

if [ -n "$used_pct" ]; then
    used_pct_int=$(printf '%.0f' "$used_pct")
    color=$(rate_color "$used_pct_int")
    bar=$(make_bar10 "$used_pct_int")
    if [ -n "$input_tokens" ] && [ -n "$context_size" ]; then
        used_fmt=$(fmt_k "$input_tokens")
        total_fmt=$(fmt_k "$context_size")
        token_str="${color}${bar} ${used_pct_int}% · ${used_fmt}/${total_fmt}${G1}${timer_str}"
    else
        token_str="${color}${bar} ${used_pct_int}%${G1}${timer_str}"
    fi
else
    token_str="${G2}no data${G1}${timer_str}"
fi

# --- Rate limits ---
rate_str=""
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$five_h_pct" ] && [ -n "$five_h_reset" ]; then
    pct_int=$(printf '%.0f' "$five_h_pct")
    c=$(rate_color "$pct_int")
    bar=$(make_bar5 "$pct_int")
    reset=$(fmt_reset "$five_h_reset")
    rate_str="${rate_str} ${G2}│${G1} ${c}${bar}${G1} ${G2}5h in${G1} ${reset}"
fi

if [ -n "$seven_d_pct" ] && [ -n "$seven_d_reset" ]; then
    pct_int=$(printf '%.0f' "$seven_d_pct")
    c=$(rate_color "$pct_int")
    bar=$(make_bar5 "$pct_int")
    reset=$(date -r "$seven_d_reset" +"%a")
    rate_str="${rate_str} · ${c}${bar}${G1} ${G2}7d on${G1} ${reset}"
fi

# --- Sunrise / sunset ---------------------------------------------------------
# Computed locally with the NOAA sunrise equation and cached once per day. This
# script runs on every render, so neither a network call nor a python start-up
# per render is affordable; the cache makes the common path a single file read.
# The cache is one line of four epochs -- today's rise and set, then tomorrow's
# -- which is enough to name the next two events at any hour. Checked against
# sunrise-sunset.org for Regina: agrees to within about a minute.
#
# Override the location with CLAUDE_SUN_LAT / CLAUDE_SUN_LON (east-positive).
SUN_LAT="${CLAUDE_SUN_LAT:-50.4452}"        # Regina, SK
SUN_LON="${CLAUDE_SUN_LON:--104.6189}"
sun_dir="$HOME/.cache/claude-statusline"
sun_cache="$sun_dir/sun-$(date +%Y%m%d)"

if [ ! -s "$sun_cache" ]; then
    mkdir -p "$sun_dir" 2>/dev/null
    rm -f "$sun_dir"/sun-* 2>/dev/null       # yesterday's is dead weight
    python3 - "$SUN_LAT" "$SUN_LON" >"$sun_cache" 2>/dev/null <<'PYSUN'
import math, sys, datetime

def sun_times(lat, lon_east, n):
    # Solar transit falls LATER in UT the further west you are, which is why an
    # east-positive longitude is subtracted here (Regina: +0.29 d onto 12:00 UT).
    Js = n - lon_east/360.0
    M  = (357.5291 + 0.98560028*Js) % 360
    Mr = math.radians(M)
    C  = 1.9148*math.sin(Mr) + 0.0200*math.sin(2*Mr) + 0.0003*math.sin(3*Mr)
    lam  = (M + C + 180 + 102.9372) % 360
    lamr = math.radians(lam)
    Jt = 2451545.0 + Js + 0.0053*math.sin(Mr) - 0.0069*math.sin(2*lamr)
    decl = math.asin(math.sin(lamr)*math.sin(math.radians(23.4397)))
    latr = math.radians(lat)
    denom = math.cos(latr)*math.cos(decl)
    if abs(denom) < 1e-12:
        return None, None
    cosw = (math.sin(math.radians(-0.833)) - math.sin(latr)*math.sin(decl))/denom
    if cosw > 1 or cosw < -1:
        return None, None                 # polar day/night: segment is omitted
    w = math.degrees(math.acos(cosw))
    u = lambda j: (j - 2440587.5)*86400.0
    return u(Jt - w/360.0), u(Jt + w/360.0)

lat, lon = float(sys.argv[1]), float(sys.argv[2])
today = datetime.date.today()
out = []
for off in (0, 1):
    d = today + datetime.timedelta(days=off)
    n = round(d.toordinal() + 1721424.5 - 2451545.0 + 0.0008)
    r, s = sun_times(lat, lon, n)
    out += [r, s]
if any(v is None for v in out):
    sys.exit(1)
print(" ".join(str(int(round(v))) for v in out))
PYSUN
fi

# 6:22a / 7:31p -- the compact clock style used elsewhere in this bar.
fmt_clock() {
    # One date(1) fork, and the meridiem folded without another: this runs on
    # every render, twice.
    local s ap
    s=$(date -r "$1" '+%-l:%M %p')
    ap=${s##* }
    case "$ap" in AM) ap=a ;; PM) ap=p ;; *) ap= ;; esac
    printf "%s%s" "${s% *}" "$ap"
}

# Top line carries the next sun event, bottom line the one after, so the pair
# always reads forwards in time no matter what hour it is.
sun_next=""
sun_next2=""
if [ -s "$sun_cache" ]; then
    read -r sr1 ss1 sr2 ss2 < "$sun_cache"
    if [ -n "$sr1" ] && [ -n "$ss1" ] && [ -n "$sr2" ] && [ -n "$ss2" ]; then
        now_epoch=$(date +%s)
        if   [ "$now_epoch" -lt "$sr1" ]; then e1=$sr1; c1=$SUN_RISE; e2=$ss1; c2=$SUN_SET
        elif [ "$now_epoch" -lt "$ss1" ]; then e1=$ss1; c1=$SUN_SET;  e2=$sr2; c2=$SUN_RISE
        else                                   e1=$sr2; c1=$SUN_RISE; e2=$ss2; c2=$SUN_SET
        fi
        sun_next="${G1}${c1} $(fmt_clock "$e1")"
        sun_next2="${G1}${c2} $(fmt_clock "$e2")"
    fi
fi

# --- Claude Code version ---
# Read the running session's version straight from the statusline JSON input — always
# accurate, no cache. If the field is ever absent, leave it empty; the bottom-line
# assembly below omits the "· v.X" segment cleanly rather than showing a stale number.
claude_version=$(echo "$input" | jq -r '.version // empty')

# --- Working directory ---
raw_cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$raw_cwd" ] && raw_cwd="$PWD"
cwd="${raw_cwd/#$HOME/~}"

# --- Git branch ---
branch=$(git -C "$raw_cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
branch_str=""
[ -n "$branch" ] && branch_str=" │  ${branch}"

# --- Bottom line: Model (default color) · v.X.X.XXX │~/cwd  branch (dimmed) ---
dir_branch="${G2}${cwd}${branch_str}${G1}"

if [ -n "$model" ] && [ -n "$claude_version" ]; then
    bottom_line="${model}${G2} · v.${claude_version} │ ${G1}${dir_branch}"
elif [ -n "$model" ]; then
    bottom_line="${model}${G2} │ ${G1}${dir_branch}"
else
    bottom_line="${dir_branch}"
fi

# --- Right-align the sun segments (space-between) -----------------------------
# The harness gives this script no tty and no width field in its JSON, but it
# does export COLUMNS -- that is the only width source available here.
#
# Measuring is safe to do by character count: LANG is UTF-8 so bash counts
# characters rather than bytes, and every glyph used in this bar (box-drawing,
# blocks, the Powerline branch, the two sun icons) has an identical 600-unit
# advance in FiraMonoNF, so one character is exactly one column.
#
# vis_len strips the colour codes first. Those are literal "\e[...m" text in
# these variables -- printf %b only expands them at output time -- so they are
# removed with plain parameter expansion, no subprocess, on a script that runs
# on every render.
vis_len() {
    local s=$1 out="" e=$'\033'
    # Two kinds of colour code end up in these strings and both must go:
    #   - literal "\e[...m" TEXT, from the G1/G2/SB_* constants, which printf %b
    #     only turns into escapes at output time; and
    #   - real ESC bytes, which rate_color() emits directly because printf
    #     expands \e inside its format string.
    # Missing the second kind silently over-counts by 7 columns per colour.
    while [[ $s == *'\e['* ]]; do
        out+=${s%%\\e\[*}
        s=${s#*\\e\[}
        s=${s#*m}
    done
    out+=$s
    s=$out
    out=""
    while [[ $s == *"$e["* ]]; do
        out+=${s%%$e\[*}
        s=${s#*$e\[}
        s=${s#*m}
    done
    out+=$s
    printf '%s' "${#out}"
}

# Hold a few columns back from COLUMNS, or the harness truncates the tail with
# an ellipsis and eats the clock.
#
# It is NOT a plain width shortage and NOT the glyphs. Measured on this machine
# with the RULER mode above: at COLUMNS=187 a pure-ASCII line of exactly 187
# visible characters renders in full, and so do lines containing the Nerd Font
# sun icons or the block/box characters -- those are all counted at the width
# they actually draw. Only lines carrying ANSI colour codes get cut, so the
# harness charges some width for the escapes themselves even though they render
# as nothing. At this bar's escape density (15 sequences on the top line,
# 7 on the bottom) the overcharge measures 4 columns: a 2-column margin still
# truncates, 4 is clean.
#
# Re-measure with the ruler if the bar's colour usage changes materially:
#   touch ~/.cache/claude-statusline/RULER   # bar becomes a margin sweep
#   rm    ~/.cache/claude-statusline/RULER   # back to normal
# then set this to the first margin that prints its label in full.
SL_RIGHT_MARGIN=4

pad1=""
pad2=""
cols=${COLUMNS:-0}
[ "$cols" -gt 0 ] && cols=$(( cols - SL_RIGHT_MARGIN ))
if [ "$cols" -gt 0 ]; then
    if [ -n "$sun_next" ]; then
        n1=$(( cols - $(vis_len "${token_str}${rate_str}") - $(vis_len "$sun_next") ))
        [ "$n1" -lt 1 ] && n1=1
        pad1=$(printf "%${n1}s" "")
    fi
    if [ -n "$sun_next2" ]; then
        n2=$(( cols - $(vis_len "$bottom_line") - $(vis_len "$sun_next2") ))
        [ "$n2" -lt 1 ] && n2=1
        pad2=$(printf "%${n2}s" "")
    fi
else
    # No COLUMNS: fall back to a plain gap rather than guessing a width.
    [ -n "$sun_next" ]  && pad1="  "
    [ -n "$sun_next2" ] && pad2="  "
fi

printf "%b%b%b%s%b%b\n%b%s%b%b" \
    "${SB_ON}${G1}" "$token_str" "$rate_str" "$pad1" "$sun_next" "$SB_OFF" \
    "${SB_ON}${G1}${bottom_line}" "$pad2" "$sun_next2" "$SB_OFF"
