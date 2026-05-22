#!/usr/bin/env bash

input=$(cat)

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
        token_str="${color}${bar} ${used_pct_int}% · ${used_fmt}/${total_fmt}\e[m${timer_str}"
    else
        token_str="${color}${bar} ${used_pct_int}%\e[m${timer_str}"
    fi
else
    token_str="\e[2mno data\e[m${timer_str}"
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
    rate_str="${rate_str} \e[2m│\e[m ${c}${bar}\e[m \e[2m5h in\e[m ${reset}"
fi

if [ -n "$seven_d_pct" ] && [ -n "$seven_d_reset" ]; then
    pct_int=$(printf '%.0f' "$seven_d_pct")
    c=$(rate_color "$pct_int")
    bar=$(make_bar5 "$pct_int")
    reset=$(date -r "$seven_d_reset" +"%a")
    rate_str="${rate_str} · ${c}${bar}\e[m \e[2m7d on\e[m ${reset}"
fi

# --- Claude Code version (cached hourly) ---
version_cache="/tmp/claude-version-cache"
version_mtime=$(stat -f%m "$version_cache" 2>/dev/null || echo 0)
cache_age=$(( $(date +%s) - version_mtime ))
if [ ! -f "$version_cache" ] || [ "$cache_age" -gt 3600 ]; then
    claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 > "$version_cache"
fi
claude_version=$(cat "$version_cache" 2>/dev/null)

# --- Working directory ---
raw_cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$raw_cwd" ] && raw_cwd="$PWD"
cwd="${raw_cwd/#$HOME/~}"

# --- Git branch ---
branch=$(git -C "$raw_cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
branch_str=""
[ -n "$branch" ] && branch_str=" │  ${branch}"

# --- Bottom line: Model (default color) · v.X.X.XXX │~/cwd  branch (dimmed) ---
dir_branch="\e[2m${cwd}${branch_str}\e[m"

if [ -n "$model" ] && [ -n "$claude_version" ]; then
    bottom_line="${model}\e[2m · v.${claude_version} │ \e[m${dir_branch}"
elif [ -n "$model" ]; then
    bottom_line="${model}\e[2m │ \e[m${dir_branch}"
else
    bottom_line="${dir_branch}"
fi

printf "%b%b\n%b" "$token_str" "$rate_str" "$bottom_line"
