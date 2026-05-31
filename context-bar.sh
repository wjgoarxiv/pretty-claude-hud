#!/bin/bash

# Color theme: gray, orange, blue, teal, green, lavender, rose, gold, slate, cyan
COLOR="${CLAUDE_HUD_THEME:-blue}"
HUD_SEP="${CLAUDE_HUD_SEP:-│}"
ICON_DIR="${CLAUDE_HUD_ICON_DIR:-󰉋}"
ICON_GIT="${CLAUDE_HUD_ICON_GIT:-󰊢}"

# Color codes
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'  # explicit gray for default text
C_BAR_EMPTY='\033[38;5;238m'
C_YELLOW='\033[38;5;178m'
C_RED='\033[38;5;167m'
C_GREEN='\033[38;5;71m'
case "$COLOR" in
    orange)   C_ACCENT='\033[38;5;173m' ;;
    blue)     C_ACCENT='\033[38;5;74m' ;;
    teal)     C_ACCENT='\033[38;5;66m' ;;
    green)    C_ACCENT='\033[38;5;71m' ;;
    lavender) C_ACCENT='\033[38;5;139m' ;;
    rose)     C_ACCENT='\033[38;5;132m' ;;
    gold)     C_ACCENT='\033[38;5;136m' ;;
    slate)    C_ACCENT='\033[38;5;60m' ;;
    cyan)     C_ACCENT='\033[38;5;37m' ;;
    *)        C_ACCENT="$C_GRAY" ;;  # gray: all same color
esac

if [[ -n "${NO_COLOR:-}" || "${CLAUDE_HUD_NO_COLOR:-0}" == "1" ]]; then
    C_RESET=''
    C_GRAY=''
    C_BAR_EMPTY=''
    C_YELLOW=''
    C_RED=''
    C_GREEN=''
    C_ACCENT=''
fi

input=$(cat)

# Extract model, directory, and cwd
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"')
if [[ "$model" == *"[1m]"* && "${ANTHROPIC_BASE_URL:-}" == *"z.ai"* ]]; then
    model="${model//[1m]/[200k]}"
fi
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [[ -n "$cwd" ]]; then
    dir=$(basename "$cwd" 2>/dev/null || echo "?")
else
    dir="?"
fi
[[ -z "$dir" ]] && dir="?"

# Get git branch, uncommitted file count, and sync status
branch=""
git_status=""
if [[ -n "$cwd" && -d "$cwd" ]]; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        # Count uncommitted files
        file_count=$(git -C "$cwd" --no-optional-locks status --porcelain -uall 2>/dev/null | wc -l | tr -d ' ')

        # Check sync status with upstream
        sync_status=""
        upstream=$(git -C "$cwd" rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        if [[ -n "$upstream" ]]; then
            # Get last fetch time
            fetch_head="$cwd/.git/FETCH_HEAD"
            fetch_ago=""
            if [[ -f "$fetch_head" ]]; then
                fetch_time=$(stat -f %m "$fetch_head" 2>/dev/null || stat -c %Y "$fetch_head" 2>/dev/null)
                if [[ -n "$fetch_time" ]]; then
                    now=$(date +%s)
                    diff=$((now - fetch_time))
                    if [[ $diff -lt 60 ]]; then
                        fetch_ago="<1m ago"
                    elif [[ $diff -lt 3600 ]]; then
                        fetch_ago="$((diff / 60))m ago"
                    elif [[ $diff -lt 86400 ]]; then
                        fetch_ago="$((diff / 3600))h ago"
                    else
                        fetch_ago="$((diff / 86400))d ago"
                    fi
                fi
            fi

            counts=$(git -C "$cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
            ahead=$(echo "$counts" | cut -f1)
            behind=$(echo "$counts" | cut -f2)
            if [[ "$ahead" -eq 0 && "$behind" -eq 0 ]]; then
                if [[ -n "$fetch_ago" ]]; then
                    sync_status="synced ${fetch_ago}"
                else
                    sync_status="synced"
                fi
            elif [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
                sync_status="${ahead} ahead"
            elif [[ "$ahead" -eq 0 && "$behind" -gt 0 ]]; then
                sync_status="${behind} behind"
            else
                sync_status="${ahead} ahead, ${behind} behind"
            fi
        else
            sync_status="no upstream"
        fi

        # Build git status string
        if [[ "$file_count" -eq 0 ]]; then
            git_status="(0 files uncommitted, ${sync_status})"
        elif [[ "$file_count" -eq 1 ]]; then
            # Show the actual filename when only one file is uncommitted
            single_file=$(git -C "$cwd" --no-optional-locks status --porcelain -uall 2>/dev/null | head -1 | sed 's/^...//')
            git_status="(${single_file} uncommitted, ${sync_status})"
        else
            git_status="(${file_count} files uncommitted, ${sync_status})"
        fi
    fi
fi

# Get transcript path for context calculation and last message feature
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Get context window size from JSON (accurate), but calculate tokens from transcript
# (more accurate than total_input_tokens which excludes system prompt/tools/memory)
# See: github.com/anthropics/claude-code/issues/13652
max_context=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
# GLM reports through Claude Code as 1m in some proxy paths, but GLM-5.1 is 200k.
if [[ "${ANTHROPIC_BASE_URL:-}" == *"z.ai"* && "$max_context" -gt 200000 ]]; then
    max_context=200000
fi
max_k=$((max_context / 1000))

# Calculate context bar from transcript
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_length=$(jq -s '
        map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
        last |
        if . then
            (.message.usage.input_tokens // 0) +
            (.message.usage.cache_read_input_tokens // 0) +
            (.message.usage.cache_creation_input_tokens // 0)
        else 0 end
    ' < "$transcript_path")

    # 20k baseline: includes system prompt (~3k), tools (~15k), memory (~300),
    # plus ~2k for git status, env block, XML framing, and other dynamic context
    baseline=20000
    bar_width=6

    if [[ "$context_length" -gt 0 ]]; then
        pct=$((context_length * 100 / max_context))
        pct_prefix=""
    else
        # At conversation start, ~20k baseline is already loaded
        pct=$((baseline * 100 / max_context))
        pct_prefix="~"
    fi

    [[ $pct -gt 100 ]] && pct=100

    bar=""
    step=$(( 100 / bar_width ))
    for ((i=0; i<bar_width; i++)); do
        bar_start=$((i * step))
        progress=$((pct - bar_start))
        if [[ $progress -ge $(( step * 8 / 10 )) ]]; then
            bar+="${C_ACCENT}█${C_RESET}"
        elif [[ $progress -ge $(( step * 3 / 10 )) ]]; then
            bar+="${C_ACCENT}▄${C_RESET}"
        else
            bar+="${C_BAR_EMPTY}░${C_RESET}"
        fi
    done

    ctx="${bar} ${C_GRAY}${pct_prefix}${pct}%/${max_k}k"
else
    # Transcript not available yet - show baseline estimate
    baseline=20000
    bar_width=6
    pct=$((baseline * 100 / max_context))
    [[ $pct -gt 100 ]] && pct=100

    bar=""
    step=$(( 100 / bar_width ))
    for ((i=0; i<bar_width; i++)); do
        bar_start=$((i * step))
        progress=$((pct - bar_start))
        if [[ $progress -ge $(( step * 8 / 10 )) ]]; then
            bar+="${C_ACCENT}█${C_RESET}"
        elif [[ $progress -ge $(( step * 3 / 10 )) ]]; then
            bar+="${C_ACCENT}▄${C_RESET}"
        else
            bar+="${C_BAR_EMPTY}░${C_RESET}"
        fi
    done

    ctx="${bar} ${C_GRAY}~${pct}%/${max_k}k"
fi

# --- Rate limit usage (5h / 1w) via Anthropic OAuth API ---
USAGE_CACHE="$HOME/.claude/plugins/oh-my-claudecode/.usage-cache.json"
CACHE_TTL_SUCCESS=30
CACHE_TTL_FAILURE=15

usage_5h=""
usage_1w=""
reset_5h=""
reset_1w=""

# Thresholds matching OMC HUD: green <70, yellow 70-89, red >=90
WARN_THRESHOLD=70
CRIT_THRESHOLD=90

# Get color for a percentage value
pct_color() {
    local val=$1
    if [[ $val -ge $CRIT_THRESHOLD ]]; then
        echo "$C_RED"
    elif [[ $val -ge $WARN_THRESHOLD ]]; then
        echo "$C_YELLOW"
    else
        echo "$C_GREEN"
    fi
}

# Build a colored progress bar: [████░░░░░░]
# Usage: make_bar <percent> <width>
make_bar() {
    local val=$1 width=${2:-5}
    local color
    color=$(pct_color "$val")
    local filled=$(( val * width / 100 ))
    local empty=$(( width - filled ))
    local result=""
    for ((j=0; j<filled; j++)); do result+="█"; done
    for ((j=0; j<empty; j++)); do result+="░"; done
    printf '%b' "${color}${result}${C_RESET}"
}

# Format reset time from ISO 8601 date string
# Output: (3h42m) or (2d5h) or empty
format_reset() {
    local reset_iso=$1
    [[ -z "$reset_iso" || "$reset_iso" == "null" ]] && return

    # Parse ISO date to epoch — macOS date -j -f or GNU date -d
    local reset_epoch
    reset_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${reset_iso%%.*}" +%s 2>/dev/null || \
                  date -d "$reset_iso" +%s 2>/dev/null)
    [[ -z "$reset_epoch" ]] && return

    local now_epoch
    now_epoch=$(date +%s)
    local diff=$(( reset_epoch - now_epoch ))
    [[ $diff -le 0 ]] && return

    local total_min=$(( diff / 60 ))
    local hours=$(( total_min / 60 ))
    local mins=$(( total_min % 60 ))
    local days=$(( hours / 24 ))

    if [[ $days -gt 0 ]]; then
        local rem_h=$(( hours % 24 ))
        printf '(%dd%dh)' "$days" "$rem_h"
    elif [[ $hours -gt 0 ]]; then
        printf '(%dh%dm)' "$hours" "$mins"
    else
        printf '(%dm)' "$mins"
    fi
}

get_usage_from_cache() {
    if [[ -f "$USAGE_CACHE" ]]; then
        local ts
        ts=$(jq -r '.timestamp // 0' < "$USAGE_CACHE" 2>/dev/null)
        local is_err
        is_err=$(jq -r '.error // false' < "$USAGE_CACHE" 2>/dev/null)
        local now
        now=$(($(date +%s) * 1000))  # ms
        local ttl
        if [[ "$is_err" == "true" ]]; then
            ttl=$((CACHE_TTL_FAILURE * 1000))
        else
            ttl=$((CACHE_TTL_SUCCESS * 1000))
        fi
        if [[ $((now - ts)) -lt $ttl ]]; then
            # Cache is valid — read values
            usage_5h=$(jq -r '.data.fiveHourPercent // empty' < "$USAGE_CACHE" 2>/dev/null)
            usage_1w=$(jq -r '.data.weeklyPercent // empty' < "$USAGE_CACHE" 2>/dev/null)
            reset_5h=$(jq -r '.data.fiveHourResetsAt // empty' < "$USAGE_CACHE" 2>/dev/null)
            reset_1w=$(jq -r '.data.weeklyResetsAt // empty' < "$USAGE_CACHE" 2>/dev/null)
            return 0
        fi
    fi
    return 1
}

fetch_usage_fresh() {
    # Get OAuth token from macOS Keychain first, then file fallback
    local token=""
    if [[ "$(uname)" == "Darwin" ]]; then
        local kc_raw
        kc_raw=$(/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [[ -n "$kc_raw" ]]; then
            token=$(echo "$kc_raw" | jq -r '.claudeAiOauth.accessToken // .accessToken // empty' 2>/dev/null)
        fi
    fi
    if [[ -z "$token" && -f "$HOME/.claude/.credentials.json" ]]; then
        token=$(jq -r '.claudeAiOauth.accessToken // .accessToken // empty' < "$HOME/.claude/.credentials.json" 2>/dev/null)
    fi
    [[ -z "$token" ]] && return 1

    # Call API (10s timeout)
    local resp
    resp=$(curl -sf --max-time 10 \
        -H "Authorization: Bearer ${token}" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    [[ -z "$resp" ]] && return 1

    usage_5h=$(echo "$resp" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    usage_1w=$(echo "$resp" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    reset_5h=$(echo "$resp" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
    reset_1w=$(echo "$resp" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

    # Clamp to 0-100 integers
    [[ -n "$usage_5h" ]] && usage_5h=$(printf '%.0f' "$usage_5h") && [[ $usage_5h -gt 100 ]] && usage_5h=100
    [[ -n "$usage_1w" ]] && usage_1w=$(printf '%.0f' "$usage_1w") && [[ $usage_1w -gt 100 ]] && usage_1w=100

    # Write cache (include reset times)
    local cache_dir
    cache_dir=$(dirname "$USAGE_CACHE")
    [[ ! -d "$cache_dir" ]] && mkdir -p "$cache_dir"
    local now_ms=$(( $(date +%s) * 1000 ))
    local r5="${reset_5h:-null}"
    local rw="${reset_1w:-null}"
    [[ "$r5" != "null" ]] && r5="\"$r5\""
    [[ "$rw" != "null" ]] && rw="\"$rw\""
    cat > "$USAGE_CACHE" <<CEOF
{"timestamp":${now_ms},"data":{"fiveHourPercent":${usage_5h:-0},"weeklyPercent":${usage_1w:-0},"fiveHourResetsAt":${r5},"weeklyResetsAt":${rw}},"error":false}
CEOF
    return 0
}

if [[ -n "${CLAUDE_HUD_TEST_USAGE:-}" ]]; then
    IFS=',' read -ra usage_parts <<< "$CLAUDE_HUD_TEST_USAGE"
    for part in "${usage_parts[@]}"; do
        key="${part%%=*}"
        value="${part#*=}"
        case "$key" in
            5h) usage_5h="$value" ;;
            1w|wk) usage_1w="$value" ;;
            reset5) reset_5h="$value" ;;
            reset1|resetw) reset_1w="$value" ;;
        esac
    done
else
    # Try cache first, then fetch fresh
    if ! get_usage_from_cache; then
        fetch_usage_fresh 2>/dev/null || true
    fi
fi

usage_str=""
if [[ -n "$usage_5h" && -n "$usage_1w" ]]; then
    local_c5=$(pct_color "$usage_5h")
    local_c1=$(pct_color "$usage_1w")
    reset_5h_str=$(format_reset "$reset_5h")
    reset_1w_str=$(format_reset "$reset_1w")
    usage_str=" ${C_GRAY}${HUD_SEP} 5h [$(make_bar "$usage_5h")]${local_c5}${usage_5h}%${C_RESET}"
    [[ -n "$reset_5h_str" ]] && usage_str+="${C_GRAY}${reset_5h_str}${C_RESET}"
    usage_str+=" ${C_GRAY}· wk [$(make_bar "$usage_1w")]${local_c1}${usage_1w}%${C_RESET}"
    [[ -n "$reset_1w_str" ]] && usage_str+="${C_GRAY}${reset_1w_str}${C_RESET}"
fi

# Build output: Model | Dir | Branch (uncommitted) | Context | Usage
output="${C_ACCENT}✦ ${model}${C_GRAY} ${HUD_SEP} ${ICON_DIR} ${dir}"
[[ -n "$branch" ]] && output+=" ${HUD_SEP} ${ICON_GIT} ${branch} ${git_status}"
output+=" ${HUD_SEP} ctx ${ctx}${usage_str}${C_RESET}"

printf '%b\n' "$output"

# Get user's last message (text only, not tool results, skip unhelpful messages)
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    # Calculate visible length (without ANSI codes) - 10 chars for bar + content
    plain_output="${model} ${HUD_SEP} ${ICON_DIR} ${dir}"
    [[ -n "$branch" ]] && plain_output+=" ${HUD_SEP} ${ICON_GIT} ${branch} ${git_status}"
    plain_output+=" ${HUD_SEP} ctx xxxxxx ${pct}%/${max_k}k"
    max_len=${#plain_output}
    last_user_msg=$(jq -rs '
        # Messages to skip (not useful as context)
        def is_unhelpful:
            startswith("[Request interrupted") or
            startswith("[Request cancelled") or
            . == "";

        [.[] | select(.type == "user") |
         select(.message.content | type == "string" or
                (type == "array" and any(.[]; .type == "text")))] |
        reverse |
        map(.message.content |
            if type == "string" then .
            else [.[] | select(.type == "text") | .text] | join(" ") end |
            gsub("\n"; " ") | gsub("  +"; " ")) |
        map(select(is_unhelpful | not)) |
        first // ""
    ' < "$transcript_path" 2>/dev/null)

    if [[ -n "$last_user_msg" ]]; then
        if [[ ${#last_user_msg} -gt $max_len ]]; then
            echo "└─ 💬 ${last_user_msg:0:$((max_len - 3))}..."
        else
            echo "└─ 💬 ${last_user_msg}"
        fi
    fi
fi
