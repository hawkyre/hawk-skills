#!/usr/bin/env bash
# Force C locale so printf '%.0f' works regardless of the user's locale
# (e.g. de_DE uses comma decimal separator and would error on "8.5").
export LC_ALL=C

# Locate jq: respect PATH but also check common Homebrew locations.
JQ=$(command -v jq 2>/dev/null)
if [ -z "$JQ" ]; then
  for candidate in /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
    [ -x "$candidate" ] && { JQ="$candidate"; break; }
  done
fi

input=$(cat)

if [ -z "$JQ" ]; then
  printf "claude (jq not found)"
  exit 0
fi

dir=$($JQ -r '.workspace.current_dir // .cwd // ""' <<<"$input")
cwd=$($JQ -r '.cwd // .workspace.current_dir // ""' <<<"$input")
worktree=$($JQ -r '.worktree.name // empty' <<<"$input")
# In a worktree, the project root is the original (non-worktree) cwd.
project_root=$($JQ -r '.worktree.original_cwd // .workspace.current_dir // .cwd // ""' <<<"$input")
pct=$($JQ -r '.context_window.used_percentage // empty' <<<"$input")
ctx_size=$($JQ -r '.context_window.context_window_size // empty' <<<"$input")
vim_mode=$($JQ -r '.vim.mode // empty' <<<"$input")

project=$(basename "$project_root")

branch=""
if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git --no-optional-locks -C "$dir" -c gc.auto=0 branch --show-current 2>/dev/null)
fi

subpath=""
if [ -n "$cwd" ] && [ -n "$dir" ] && [ "$cwd" != "$dir" ]; then
  case "$cwd" in
    "$dir"/*) subpath=$(basename "$cwd") ;;
  esac
fi

# Palette (256-color)
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[38;5;244m'
PROJ=$'\033[38;5;39m'
BRANCH=$'\033[38;5;179m'
WT=$'\033[38;5;141m'
SUB=$'\033[38;5;108m'
VIM=$'\033[38;5;205m'
GREEN=$'\033[38;5;108m'
YELLOW=$'\033[38;5;179m'
RED=$'\033[38;5;203m'

SEP="${DIM}·${RESET}"

pct_color() {
  # awk coerces non-numeric to 0, which falls to GREEN — safe default.
  local p
  p=$(awk -v x="$1" 'BEGIN { printf "%d", x+0 }')
  if   [ "$p" -ge 80 ]; then printf "%s" "$RED"
  elif [ "$p" -ge 50 ]; then printf "%s" "$YELLOW"
  else                       printf "%s" "$GREEN"
  fi
}

# Format a token count compactly: 523 → "523", 50480 → "50k", 1000000 → "1M".
fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n+0 < 1000) printf "%d", n
    else if (n+0 < 1000000) printf "%dk", n/1000
    else if (n+0 < 10000000) printf "%.1fM", n/1000000
    else printf "%dM", n/1000000
  }'
}

# Numeric guard: pct may be empty or non-numeric (e.g. "null" early in
# session). awk's `n+0 == n` only holds for valid numeric strings.
is_numeric() { awk -v n="$1" 'BEGIN { exit !(n+0 == n && n != "") }'; }

parts=()
parts+=("${PROJ}${BOLD}📁 ${project}${RESET}")

[ -n "$branch" ] && parts+=("${BRANCH}🌿 ${branch}${RESET}")

# Worktree only if it differs from the branch (otherwise duplicate info).
if [ -n "$worktree" ] && [ "$worktree" != "$branch" ]; then
  parts+=("${WT}🌳 ${worktree}${RESET}")
fi

[ -n "$subpath" ] && parts+=("${SUB}📂 ${subpath}${RESET}")

if [ -n "$pct" ] && is_numeric "$pct"; then
  c=$(pct_color "$pct")
  pct_str=$(awk -v p="$pct" 'BEGIN { printf "%.0f%%", p+0 }')
  if [ -n "$ctx_size" ] && is_numeric "$ctx_size"; then
    used_tokens=$(awk -v p="$pct" -v s="$ctx_size" 'BEGIN { printf "%d", p*s/100 }')
    parts+=("${c}🧠 ${pct_str} ($(fmt_tokens "$used_tokens")/$(fmt_tokens "$ctx_size"))${RESET}")
  else
    parts+=("${c}🧠 ${pct_str}${RESET}")
  fi
fi

# Join with separators.
out=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    out="${parts[$i]}"
  else
    out="${out} ${SEP} ${parts[$i]}"
  fi
done
printf "%s" "$out"

[ -n "$vim_mode" ] && printf "  ${VIM}[%s]${RESET}" "$vim_mode"
