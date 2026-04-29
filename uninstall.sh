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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --all)     all=1; shift ;;
    --prefix)
      if [[ $# -lt 2 ]]; then fail "--prefix requires a value"; exit 2; fi
      prefix_filter="$2"; prefix_filter_set=1
      shift 2
      ;;
    -h|--help)
      banner
      cat <<EOF
${BOLD}Usage${RESET}
  ./uninstall.sh                 interactive: pick which installs to remove
  ./uninstall.sh --dry-run       show plan, do nothing
  ./uninstall.sh --all           remove every detected installation, no prompts
  ./uninstall.sh --prefix hawk-  scope to a single prefix
  ./uninstall.sh --prefix ""     scope to unprefixed installs

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
read_description() {
  local md="$1"
  [[ -f "$md" ]] || { printf ''; return; }
  awk '
    /^---[[:space:]]*$/ { fence++; if (fence == 2) exit; next }
    fence == 1 && /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      print
      exit
    }
  ' "$md"
}

# Sort known skill names by length, descending. Longest-suffix wins so
# "code-audit" doesn't shadow "code-audit-hardcore" during prefix detection.
known_names=()
while IFS= read -r line; do
  known_names+=("${line#* }")
done < <(
  for src in "$SOURCE_DIR"/*/; do
    n="$(basename "$src")"
    printf '%d %s\n' "${#n}" "$n"
  done | sort -rn
)

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

if (( count == 0 )); then
  warn "nothing selected — exiting"
  exit 0
fi

# ─── summary ───────────────────────────────────────────────────────────────────

printf '\n'
if (( dry_run )); then
  boxed \
    "${BOLD}Dry-run complete${RESET}" \
    "${DIM}$count installation(s) would be removed${RESET}"
else
  boxed \
    "${GREEN}✓${RESET} ${BOLD}Removed $count installation(s)${RESET}" \
    "" \
    "${BOLD}Reinstall${RESET}  ${DIM}./install.sh${RESET}" \
    "${BOLD}Docs${RESET}       ${DIM}https://github.com/${REPO}${RESET}"
fi
printf '\n'
