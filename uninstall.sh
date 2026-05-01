#!/usr/bin/env bash
# hawk-skills — uninstaller
# https://github.com/hawkyre/hawk-skills
#
# Removes hawk-skills installations from ~/.claude/skills/.
#
# Usage:
#   ./uninstall.sh                 interactive picker
#   ./uninstall.sh --dry-run       show plan, do nothing
#   ./uninstall.sh --all           remove every detected installation, no prompts
#   ./uninstall.sh --prefix hawk-  scope to a single prefix
#   ./uninstall.sh --prefix ""     scope to unprefixed installs
#   ./uninstall.sh --statusline    also remove the hawk statusline
#   ./uninstall.sh --no-statusline skip the statusline prompt
#
# Must be run from a hawk-skills checkout (the script reads skills/ to know
# which directory names belong to us).

set -euo pipefail

REPO="hawkyre/hawk-skills"

# ─── colors ────────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
  HIDE_CURSOR=$'\033[?25l'
  SHOW_CURSOR=$'\033[?25h'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; RESET=""
  HIDE_CURSOR=""; SHOW_CURSOR=""
fi

# ─── primitives ────────────────────────────────────────────────────────────────

step() { printf '%s→%s %s\n'   "${BLUE}"   "${RESET}" "$1"; }
ok()   { printf '%s✓%s %s\n'   "${GREEN}"  "${RESET}" "$1"; }
warn() { printf '%s!%s %s\n'   "${YELLOW}" "${RESET}" "$1"; }
fail() { printf '%s✗%s %s\n'   "${RED}"    "${RESET}" "$1" >&2; }
sub()  { printf '   %s%s%s\n'  "${DIM}"    "$1" "${RESET}"; }
hr()   { printf '%s──────────────────────────────────────────────────%s\n' "${DIM}" "${RESET}"; }

banner() {
  printf '\n'
  printf '%s' "${CYAN}"
  cat <<'EOF'
   _                    _          _    _ _ _
  | |                  | |        | |  (_) | |
  | |__   __ ___      _| | __  ___| | ___| | |___
  | '_ \ / _` \ \ /\ / / |/ / / __| |/ / | | / __|
  | | | | (_| |\ V  V /|   <  \__ \   <| | | \__ \
  |_| |_|\__,_| \_/\_/ |_|\_\ |___/_|\_\_|_|_|___/
EOF
  printf '%s\n' "${RESET}"
  printf '   %suninstall%s\n\n' "${DIM}" "${RESET}"
}

# boxed: print a 2-column box around the given lines (mirrors install.sh)
boxed() {
  local lines=("$@")
  local maxlen=0
  local strip
  for line in "${lines[@]}"; do
    strip="$(printf '%s' "$line" | sed -E $'s/\033\\[[0-9;?]*[a-zA-Z]//g')"
    (( ${#strip} > maxlen )) && maxlen=${#strip}
  done
  local width=$((maxlen + 4))
  local border
  border="$(printf '─%.0s' $(seq 1 $width))"
  printf '%s╭%s╮%s\n' "${DIM}" "$border" "${RESET}"
  for line in "${lines[@]}"; do
    strip="$(printf '%s' "$line" | sed -E $'s/\033\\[[0-9;?]*[a-zA-Z]//g')"
    local pad=$((maxlen - ${#strip}))
    printf '%s│%s  %s%*s  %s│%s\n' "${DIM}" "${RESET}" "$line" "$pad" "" "${DIM}" "${RESET}"
  done
  printf '%s╰%s╯%s\n' "${DIM}" "$border" "${RESET}"
}

cleanup() { printf '%s' "${SHOW_CURSOR}"; }
trap cleanup EXIT INT TERM

# ─── arg parsing ───────────────────────────────────────────────────────────────

dry_run=0
all=0
prefix_filter=""
prefix_filter_set=0
statusline_choice=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --all)     all=1; shift ;;
    --prefix)
      if [[ $# -lt 2 ]]; then fail "--prefix requires a value"; exit 2; fi
      prefix_filter="$2"; prefix_filter_set=1
      shift 2
      ;;
    --statusline)    statusline_choice="yes"; shift ;;
    --no-statusline) statusline_choice="no";  shift ;;
    -h|--help)
      banner
      cat <<EOF
${BOLD}Usage${RESET}
  ./uninstall.sh                 interactive: pick which installs to remove
  ./uninstall.sh --dry-run       show plan, do nothing
  ./uninstall.sh --all           remove every detected installation, no prompts
  ./uninstall.sh --prefix hawk-  scope to a single prefix
  ./uninstall.sh --prefix ""     scope to unprefixed installs
  ./uninstall.sh --statusline    also remove the hawk statusline
  ./uninstall.sh --no-statusline skip the statusline prompt

${BOLD}Detection${RESET}
  An install is identified as ours when a directory under
  ~/.claude/skills/ ends with one of our skill names ${DIM}AND${RESET} its
  SKILL.md description matches the source's description. Unrelated
  skills with colliding names are left alone.

EOF
      exit 0
      ;;
    *) fail "unknown argument: $1"; exit 2 ;;
  esac
done

# ─── locate source ─────────────────────────────────────────────────────────────

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]] \
  && [[ "${BASH_SOURCE[0]}" != "bash" ]] \
  && [[ "${BASH_SOURCE[0]}" != "/dev/stdin" ]] \
  && [[ -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [[ -z "$SCRIPT_DIR" || ! -d "$SCRIPT_DIR/skills" ]]; then
  fail "uninstall.sh must be run from a hawk-skills checkout (skills/ not found)"
  sub "clone https://github.com/${REPO} and run ./uninstall.sh from inside"
  exit 1
fi

SOURCE_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

if [[ ! -d "$TARGET_DIR" ]]; then
  fail "$TARGET_DIR does not exist — nothing to uninstall"
  exit 1
fi

banner

# ─── enumerate known skills ────────────────────────────────────────────────────

# read_description <SKILL.md path> → echoes the description: line
# Trim trailing whitespace and CR so editor artifacts don't break the
# description-match safety net.
read_description() {
  local md="$1"
  [[ -f "$md" ]] || { printf ''; return; }
  awk '
    /^---[[:space:]]*$/ { fence++; if (fence == 2) exit; next }
    fence == 1 && /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      sub(/[[:space:]\r]+$/, "")
      print
      exit
    }
  ' "$md"
}

# Sort known skill names by length, descending. Longest-suffix wins so
# "code-audit" doesn't shadow "code-audit-hardcore" during prefix detection.
known_names=()
# First, gather (length, name) pairs for real skills only — underscore-
# prefixed and SKILL.md-less directories aren't skills. Done outside the
# process substitution because bash 3.2 (macOS default) can't parse
# `[[ … ]]` conditionals nested inside `< <( … )`.
unsorted=()
for src in "$SOURCE_DIR"/*/; do
  n="$(basename "$src")"
  [[ "$n" == _* ]] && continue
  [[ -f "$src/SKILL.md" ]] || continue
  unsorted+=("${#n} $n")
done
while IFS= read -r line; do
  known_names+=("${line#* }")
done < <(printf '%s\n' "${unsorted[@]}" | sort -rn)

# Pre-compute description for each known skill (for the safety check below).
known_descs=()
for i in "${!known_names[@]}"; do
  known_descs[i]="$(read_description "$SOURCE_DIR/${known_names[i]}/SKILL.md")"
done

# ─── detect installations ─────────────────────────────────────────────────────

found_dirs=()       # absolute path of each install
found_prefixes=()   # parallel: inferred prefix
found_skills=()     # parallel: matching source skill name

for dir in "$TARGET_DIR"/*/; do
  [[ -d "$dir" ]] || continue
  base="$(basename "$dir")"
  installed_md="${dir%/}/SKILL.md"
  [[ -f "$installed_md" ]] || continue
  installed_desc="$(read_description "$installed_md")"

  for i in "${!known_names[@]}"; do
    skill="${known_names[i]}"
    src_desc="${known_descs[i]}"
    if [[ "$base" == *"$skill" ]]; then
      candidate_prefix="${base%$skill}"
      # Description match is the safety net: if the SKILL.md's description
      # matches what we ship, this directory was installed by install.sh.
      if [[ -n "$src_desc" && "$installed_desc" == "$src_desc" ]]; then
        found_dirs+=("${dir%/}")
        found_prefixes+=("$candidate_prefix")
        found_skills+=("$skill")
        break
      fi
    fi
  done
done

if [[ ${#found_dirs[@]} -eq 0 ]]; then
  warn "no hawk-skills installations found in $TARGET_DIR"
  exit 0
fi

# Apply --prefix filter if set
if (( prefix_filter_set )); then
  new_dirs=(); new_prefixes=(); new_skills=()
  for i in "${!found_dirs[@]}"; do
    if [[ "${found_prefixes[i]}" == "$prefix_filter" ]]; then
      new_dirs+=("${found_dirs[i]}")
      new_prefixes+=("${found_prefixes[i]}")
      new_skills+=("${found_skills[i]}")
    fi
  done
  if [[ ${#new_dirs[@]} -eq 0 ]]; then
    warn "no installations matching prefix \"$prefix_filter\" found"
    exit 0
  fi
  found_dirs=("${new_dirs[@]}")
  found_prefixes=("${new_prefixes[@]}")
  found_skills=("${new_skills[@]}")
fi

# ─── tty detection ─────────────────────────────────────────────────────────────

tty_in=""
if [[ -e /dev/tty ]] && [[ -r /dev/tty ]] && { exec 3</dev/tty; } 2>/dev/null; then
  tty_in="/dev/tty"
fi

# Interactive picker runs by default. Skipped when --all, --prefix, or no tty.
interactive=1
if [[ -z "$tty_in" ]] || (( all )) || (( prefix_filter_set )); then
  interactive=0
fi

# ─── interactive checkbox picker ───────────────────────────────────────────────

selected=()
for _ in "${found_dirs[@]}"; do selected+=(1); done

if (( interactive )); then
  cursor=0
  drawn_rows=0

  draw() {
    local rows=0
    printf '   %sChoose installations to uninstall%s  %s↑/↓ move · space toggle · a all · n none · enter confirm · q quit%s\n' \
      "${BOLD}" "${RESET}" "${DIM}" "${RESET}"
    rows=$((rows + 1))
    hr; rows=$((rows + 1))

    local i box pointer label
    for i in "${!found_dirs[@]}"; do
      if (( selected[i] )); then box="${RED}[✓]${RESET}"; else box="${DIM}[ ]${RESET}"; fi
      if (( i == cursor )); then pointer="${CYAN}❯${RESET}"; else pointer=" "; fi
      label="$(basename "${found_dirs[i]}")"
      printf '   %s %s %s\n' "$pointer" "$box" "$label"
      rows=$((rows + 1))
    done
    hr; rows=$((rows + 1))

    printf '   %sremove from:%s %s\n' "${DIM}" "${RESET}" "${found_dirs[cursor]}"
    rows=$((rows + 1))

    drawn_rows=$rows
  }

  if (( ${BASH_VERSINFO[0]:-3} >= 4 )); then
    esc_timeout="0.05"
  else
    esc_timeout="1"
  fi

  read_key() {
    local k
    IFS= read -rsn1 k <"$tty_in"
    if [[ "$k" == $'\033' ]]; then
      local rest=""
      IFS= read -rsn2 -t "$esc_timeout" rest <"$tty_in" || rest=""
      k="$k$rest"
    fi
    printf '%s' "$k"
  }

  printf '%s' "${HIDE_CURSOR}"
  draw
  while true; do
    key="$(read_key)"
    case "$key" in
      $'\033[A'|k) (( cursor > 0 )) && cursor=$((cursor - 1)) ;;
      $'\033[B'|j) (( cursor < ${#found_dirs[@]} - 1 )) && cursor=$((cursor + 1)) ;;
      ' ')         selected[cursor]=$(( 1 - selected[cursor] )) ;;
      a|A)         for i in "${!selected[@]}"; do selected[i]=1; done ;;
      n|N)         for i in "${!selected[@]}"; do selected[i]=0; done ;;
      ''|$'\n'|$'\r') break ;;
      q|Q)         printf '%s' "${SHOW_CURSOR}"; warn "aborted"; exit 130 ;;
    esac
    printf '\033[%dA\033[J' "$drawn_rows"
    draw
  done
  printf '%s' "${SHOW_CURSOR}"
  printf '\n'
fi

# ─── uninstall ─────────────────────────────────────────────────────────────────

if (( dry_run )); then
  step "Planning uninstall ← ${BOLD}${TARGET_DIR}${RESET}"
else
  step "Uninstalling ← ${BOLD}${TARGET_DIR}${RESET}"
fi
hr

count=0
for i in "${!found_dirs[@]}"; do
  (( selected[i] )) || continue
  dir="${found_dirs[i]}"
  label="$(basename "$dir")"
  if (( dry_run )); then
    printf '   %s−%s %s %s(would remove)%s\n' "${YELLOW}" "${RESET}" "$label" "${DIM}" "${RESET}"
  else
    rm -rf "$dir"
    printf '   %s−%s %s\n' "${YELLOW}" "${RESET}" "$label"
  fi
  count=$((count + 1))
done

hr

# ─── agents ────────────────────────────────────────────────────────────────────
# Detect and remove agent files we ship. Same description-match safety net as
# skills — if an agent at ~/.claude/agents/<X>.md has a description matching
# what's in our agents/<X>.md, it's ours.

AGENTS_SRC="$SCRIPT_DIR/agents"
AGENTS_TARGET="$HOME/.claude/agents"
agents_removed=0

if [[ -d "$AGENTS_SRC" ]] && [[ -d "$AGENTS_TARGET" ]]; then
  # Build (name → description) map from source.
  src_agent_names=()
  src_agent_descs=()
  for src in "$AGENTS_SRC"/*.md; do
    [[ -f "$src" ]] || continue
    src_agent_names+=("$(basename "$src" .md)")
    src_agent_descs+=("$(read_description "$src")")
  done

  # Walk every installed agent file, check whether the suffix matches a known
  # agent AND the descriptions agree. Remove if both.
  pending_remove=()
  for installed in "$AGENTS_TARGET"/*.md; do
    [[ -f "$installed" ]] || continue
    base="$(basename "$installed" .md)"
    inst_desc="$(read_description "$installed")"
    for i in "${!src_agent_names[@]}"; do
      sname="${src_agent_names[i]}"
      sdesc="${src_agent_descs[i]}"
      if [[ "$base" == *"$sname" ]] && [[ -n "$sdesc" ]] && [[ "$inst_desc" == "$sdesc" ]]; then
        pending_remove+=("$installed")
        break
      fi
    done
  done

  if (( ${#pending_remove[@]} > 0 )); then
    if (( dry_run )); then
      step "Planning agents removal ← ${BOLD}${AGENTS_TARGET}${RESET}"
      hr
      for f in "${pending_remove[@]}"; do
        printf '   %s−%s %s %s(would remove)%s\n' "${YELLOW}" "${RESET}" "$(basename "$f")" "${DIM}" "${RESET}"
        agents_removed=$((agents_removed + 1))
      done
      hr
    else
      step "Removing agents ← ${BOLD}${AGENTS_TARGET}${RESET}"
      hr
      for f in "${pending_remove[@]}"; do
        rm -f "$f"
        printf '   %s−%s %s\n' "${YELLOW}" "${RESET}" "$(basename "$f")"
        agents_removed=$((agents_removed + 1))
      done
      hr
    fi
  fi
fi

if (( count == 0 )) && (( agents_removed == 0 )) && [[ "$statusline_choice" != "yes" ]]; then
  warn "nothing selected — exiting"
  exit 0
fi

# ─── statusline ────────────────────────────────────────────────────────────────

statusline_dest="$HOME/.claude/hawk-statusline.sh"
statusline_settings="$HOME/.claude/settings.json"
statusline_present=0
[[ -f "$statusline_dest" ]] && statusline_present=1

if (( statusline_present )) && (( interactive )) && [[ -z "$statusline_choice" ]]; then
  printf '\n'
  printf '   %sAlso remove the hawk statusline?%s %s(%s)%s\n' \
    "${BOLD}" "${RESET}" "${DIM}" "$statusline_dest" "${RESET}"
  printf '\n   %sremove? [y/N]>%s ' "${CYAN}" "${RESET}"
  IFS= read -r reply <"$tty_in" || reply=""
  case "$reply" in
    y|Y|yes|YES) statusline_choice="yes" ;;
    *)           statusline_choice="no"  ;;
  esac
  printf '\n'
fi

statusline_removed=0

if [[ "$statusline_choice" == "yes" ]]; then
  if (( dry_run )); then
    step "Planning statusline removal"
    hr
    if (( statusline_present )); then
      printf '   %s−%s hawk-statusline.sh %s(would remove)%s\n' \
        "${YELLOW}" "${RESET}" "${DIM}" "${RESET}"
    else
      printf '   %s·%s hawk-statusline.sh %s(not present)%s\n' \
        "${DIM}" "${RESET}" "${DIM}" "${RESET}"
    fi
    if [[ -f "$statusline_settings" ]] && command -v jq >/dev/null 2>&1 \
       && jq -e '.statusLine.command // "" | test("hawk-statusline\\.sh")' \
            "$statusline_settings" >/dev/null 2>&1; then
      printf '   %s−%s settings.json statusLine %s(would clear)%s\n' \
        "${YELLOW}" "${RESET}" "${DIM}" "${RESET}"
    fi
    hr
    statusline_removed=1
  else
    step "Removing statusline"
    hr
    if (( statusline_present )); then
      rm -f "$statusline_dest"
      printf '   %s−%s hawk-statusline.sh\n' "${YELLOW}" "${RESET}"
    else
      printf '   %s·%s hawk-statusline.sh %s(not present)%s\n' \
        "${DIM}" "${RESET}" "${DIM}" "${RESET}"
    fi
    if [[ -f "$statusline_settings" ]]; then
      if command -v jq >/dev/null 2>&1; then
        if jq -e '.statusLine.command // "" | test("hawk-statusline\\.sh")' \
            "$statusline_settings" >/dev/null 2>&1; then
          # Same-filesystem temp, atomic rename, collision-free backup suffix.
          tmp="$(mktemp -- "$HOME/.claude/.settings.XXXXXX")"
          if jq 'del(.statusLine)' "$statusline_settings" >"$tmp" 2>/dev/null; then
            cp "$statusline_settings" "${statusline_settings}.bak.$(date +%s)-$$"
            mv "$tmp" "$statusline_settings"
            printf '   %s−%s settings.json statusLine cleared %s(prev backed up)%s\n' \
              "${YELLOW}" "${RESET}" "${DIM}" "${RESET}"
          else
            rm -f "$tmp"
            warn "could not edit settings.json — left untouched"
          fi
        fi
      else
        warn "jq not found — settings.json left untouched (remove the statusLine block manually)"
      fi
    fi
    hr
    statusline_removed=1
  fi
fi

# ─── summary ───────────────────────────────────────────────────────────────────

printf '\n'
sl_line=""
if (( statusline_removed )); then
  sl_line="${BOLD}Statusline${RESET}  ${DIM}removed${RESET}"
fi

if (( dry_run )); then
  dry_lines=(
    "${BOLD}Dry-run complete${RESET}"
    "${DIM}$count skill(s) would be removed${RESET}"
  )
  if (( agents_removed > 0 )); then
    dry_lines+=("${DIM}$agents_removed agent(s) would be removed${RESET}")
  fi
  if [[ -n "$sl_line" ]]; then
    dry_lines+=("" "$sl_line")
  fi
  boxed "${dry_lines[@]}"
else
  lines=(
    "${GREEN}✓${RESET} ${BOLD}Removed $count skill(s)${RESET}"
  )
  if (( agents_removed > 0 )); then
    lines+=("${GREEN}✓${RESET} ${BOLD}Removed $agents_removed agent(s)${RESET}")
  fi
  lines+=(
    ""
    "${BOLD}Reinstall${RESET}  ${DIM}./install.sh${RESET}"
    "${BOLD}Docs${RESET}       ${DIM}https://github.com/${REPO}${RESET}"
  )
  if [[ -n "$sl_line" ]]; then
    lines+=("" "$sl_line")
  fi
  boxed "${lines[@]}"
fi
printf '\n'
