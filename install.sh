#!/usr/bin/env bash
# hawk-skills — opinionated Claude Code skills
# https://github.com/hawkyre/hawk-skills
#
# Quick install (no clone required):
#   curl -fsSL https://raw.githubusercontent.com/hawkyre/hawk-skills/main/install.sh | bash
#
# With flags:
#   curl -fsSL .../install.sh | bash -s -- --select         # interactive picker
#   curl -fsSL .../install.sh | bash -s -- --dry-run
#   curl -fsSL .../install.sh | bash -s -- --only code-audit
#   curl -fsSL .../install.sh | bash -s -- --prefix hawk-   # namespace all skills
#   curl -fsSL .../install.sh | bash -s -- --statusline     # also install statusline
#   curl -fsSL .../install.sh | bash -s -- --no-statusline  # skip statusline prompt
#
# From a cloned checkout:
#   ./install.sh

set -euo pipefail

REPO="hawkyre/hawk-skills"
BRANCH="main"
TARBALL_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${BRANCH}"

# ─── colors ────────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  MAG=$'\033[35m'
  CYAN=$'\033[36m'
  GREY=$'\033[90m'
  RESET=$'\033[0m'
  HIDE_CURSOR=$'\033[?25l'
  SHOW_CURSOR=$'\033[?25h'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAG=""; CYAN=""; GREY=""; RESET=""
  HIDE_CURSOR=""; SHOW_CURSOR=""
fi

# ─── primitives ────────────────────────────────────────────────────────────────

step() { printf '%s→%s %s\n'   "${BLUE}"  "${RESET}" "$1"; }
ok()   { printf '%s✓%s %s\n'   "${GREEN}" "${RESET}" "$1"; }
warn() { printf '%s!%s %s\n'   "${YELLOW}" "${RESET}" "$1"; }
fail() { printf '%s✗%s %s\n'   "${RED}"   "${RESET}" "$1" >&2; }
sub()  { printf '   %s%s%s\n'  "${DIM}"   "$1" "${RESET}"; }
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
  printf '   %sblind • parallel • independent%s\n'    "${DIM}" "${RESET}"
  printf '   %sopinionated Claude Code skills%s\n\n'  "${DIM}" "${RESET}"
}

# spinner: spinner <pid> <message>
spinner() {
  local pid=$1
  local msg=$2
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  printf '%s' "${HIDE_CURSOR}"
  while kill -0 "$pid" 2>/dev/null; do
    local frame="${frames:$((i % ${#frames})):1}"
    printf '\r\033[K  %s%s%s %s' "${CYAN}" "$frame" "${RESET}" "$msg"
    i=$((i + 1))
    sleep 0.08
  done
  printf '\r\033[K'
  printf '%s' "${SHOW_CURSOR}"
}

# boxed: print a 2-column box around the given lines
boxed() {
  local lines=("$@")
  local maxlen=0
  local strip
  for line in "${lines[@]}"; do
    # strip ANSI for length calc
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

# cleanup on any exit
TMPDIR_CLEANUP=""
cleanup() {
  printf '%s' "${SHOW_CURSOR}"
  if [[ -n "$TMPDIR_CLEANUP" && -d "$TMPDIR_CLEANUP" ]]; then
    rm -rf "$TMPDIR_CLEANUP"
  fi
}
trap cleanup EXIT INT TERM

# ─── arg parsing ───────────────────────────────────────────────────────────────

dry_run=0
only_list=()
prefix=""
prefix_set=0           # 1 = user supplied --prefix (skip interactive prompt)
statusline_choice=""   # "" = ask interactively, "yes" / "no" otherwise

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --only)
      if [[ $# -lt 2 ]]; then fail "--only requires a skill name"; exit 2; fi
      only_list+=("$2")
      shift 2
      ;;
    --statusline)    statusline_choice="yes"; shift ;;
    --no-statusline) statusline_choice="no";  shift ;;
    --prefix)
      if [[ $# -lt 2 ]]; then fail "--prefix requires a value (use --prefix '' for none)"; exit 2; fi
      case "$2" in
        --*) fail "--prefix value cannot start with -- (got '$2'; use --prefix '' for none)"; exit 2 ;;
      esac
      # Block characters that would break sed regex/replacement, filenames,
      # or shell quoting. Allows letters, digits, _, -, :, . — covers the
      # common namespace styles (`hawk-`, `h:`, `my.org.`).
      if [[ -n "$2" && ! "$2" =~ ^[a-zA-Z0-9_:.\-]+$ ]]; then
        fail "--prefix may only contain letters, digits, '_', '-', ':', '.' (got '$2')"
        exit 2
      fi
      prefix="$2"
      prefix_set=1
      shift 2
      ;;
    -h|--help)
      banner
      cat <<EOF
${BOLD}Usage${RESET}
  ./install.sh                       interactive: pick a prefix, then choose skills
  ./install.sh --dry-run             show plan, do not install
  ./install.sh --only <name>         install one skill, no prompts (repeatable)
  ./install.sh --prefix <p>          namespace skills + agents (e.g. hawk-, h:)
                                     allowed: letters/digits/_/-/:/. or '' for none
  ./install.sh --statusline          also install the hawk statusline
  ./install.sh --no-statusline       skip the statusline prompt

${BOLD}Remote (no clone required)${RESET}
  curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh | bash

EOF
      exit 0
      ;;
    *) fail "unknown argument: $1"; exit 2 ;;
  esac
done

# ─── locate source ─────────────────────────────────────────────────────────────

# When piped from curl, BASH_SOURCE is empty / non-file. When run as a script,
# the sibling skills/ dir tells us this is a local checkout.
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]] \
  && [[ "${BASH_SOURCE[0]}" != "bash" ]] \
  && [[ "${BASH_SOURCE[0]}" != "/dev/stdin" ]] \
  && [[ -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

banner

if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/skills" ]]; then
  SOURCE_DIR="$SCRIPT_DIR/skills"
  REPO_ROOT="$SCRIPT_DIR"
  sub "source: local checkout"
else
  if ! command -v curl >/dev/null 2>&1; then fail "curl is required";  exit 1; fi
  if ! command -v tar  >/dev/null 2>&1; then fail "tar is required";   exit 1; fi
  TMPDIR_CLEANUP="$(mktemp -d -t hawk-skills.XXXXXX)"
  curl -fsSL "$TARBALL_URL" -o "$TMPDIR_CLEANUP/repo.tar.gz" &
  curl_pid=$!
  spinner "$curl_pid" "Fetching from github.com/${REPO}@${BRANCH}…"
  if ! wait "$curl_pid"; then
    fail "could not download $TARBALL_URL"
    exit 1
  fi
  ok "Downloaded"
  tar -xzf "$TMPDIR_CLEANUP/repo.tar.gz" -C "$TMPDIR_CLEANUP"
  extracted="$(find "$TMPDIR_CLEANUP" -maxdepth 1 -type d -name "hawk-skills-*" | head -n 1)"
  if [[ -z "$extracted" || ! -d "$extracted/skills" ]]; then
    fail "could not locate skills/ in downloaded tarball"; exit 1
  fi
  SOURCE_DIR="$extracted/skills"
  REPO_ROOT="$extracted"
fi

STATUSLINE_SRC="$REPO_ROOT/statusline/statusline.sh"
AGENTS_SRC="$REPO_ROOT/agents"

# ─── verify target ─────────────────────────────────────────────────────────────

TARGET_DIR="$HOME/.claude/skills"

if [[ ! -d "$HOME/.claude" ]]; then
  fail "$HOME/.claude does not exist — is Claude Code installed?"
  sub "see https://docs.claude.com/claude-code"
  exit 1
fi

mkdir -p "$TARGET_DIR"

# ─── enumerate skills + descriptions ───────────────────────────────────────────

skills=()
descriptions=()
max_name_len=0

# read_description <skill_dir> → echoes the description: line from SKILL.md
# Trailing whitespace and CR are trimmed so editors that introduce them
# don't break the description-match safety net used by uninstall.
read_description() {
  local md="$1/SKILL.md"
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

for src in "$SOURCE_DIR"/*/; do
  name="$(basename "$src")"
  # Skip non-skill directories (shared fragments, support files).
  # Convention: prefix with `_` to opt out of the picker. They still
  # ship with the install (copied below) so skills can reference them.
  [[ "$name" == _* ]] && continue
  [[ -f "$src/SKILL.md" ]] || continue
  skills+=("$name")
  descriptions+=("$(read_description "$src")")
  (( ${#name} > max_name_len )) && max_name_len=${#name}
done

if [[ ${#skills[@]} -eq 0 ]]; then
  fail "no skills found in $SOURCE_DIR"
  exit 1
fi

# ─── tty detection ─────────────────────────────────────────────────────────────

tty_in=""
if [[ -e /dev/tty ]] && [[ -r /dev/tty ]] && { exec 3</dev/tty; } 2>/dev/null; then
  tty_in="/dev/tty"
fi

# Interactive flow runs by default when we have a tty AND --only wasn't given.
interactive=1
if [[ -z "$tty_in" ]] || [[ ${#only_list[@]} -gt 0 ]]; then
  interactive=0
fi

# ─── prompt for prefix ─────────────────────────────────────────────────────────

if (( interactive )) && ! (( prefix_set )); then
  printf '\n'
  printf '   %sNamespace prefix?%s %s(optional — press enter for none)%s\n' \
    "${BOLD}" "${RESET}" "${DIM}" "${RESET}"
  printf '   %slets these skills coexist with same-named project skills%s\n' \
    "${DIM}" "${RESET}"
  printf '   %sex: prefix %shawk-%s installs %scap%s as %shawk-cap%s\n' \
    "${DIM}" "${BOLD}" "${RESET}${DIM}" "${BOLD}" "${RESET}${DIM}" "${BOLD}" "${RESET}"
  printf '\n   %sprefix>%s ' "${CYAN}" "${RESET}"
  IFS= read -r prefix <"$tty_in" || prefix=""
  prefix="${prefix#"${prefix%%[![:space:]]*}"}"   # ltrim
  prefix="${prefix%"${prefix##*[![:space:]]}"}"   # rtrim
  if [[ -n "$prefix" && ! "$prefix" =~ ^[a-zA-Z0-9_:.\-]+$ ]]; then
    fail "prefix may only contain letters, digits, '_', '-', ':', '.' (got '$prefix')"
    exit 2
  fi
  printf '\n'
fi

# ─── interactive checkbox picker ───────────────────────────────────────────────

if (( interactive )); then
  # selected[i] = 1 if checked. default: all selected.
  selected=()
  for _ in "${skills[@]}"; do selected+=(1); done
  cursor=0

  # Detect terminal width for word-wrapping the description block.
  term_cols="${COLUMNS:-0}"
  if (( term_cols == 0 )) && command -v tput >/dev/null 2>&1; then
    term_cols="$(tput cols </dev/tty 2>/dev/null || echo 0)"
  fi
  (( term_cols == 0 )) && term_cols=100
  wrap_width=$(( term_cols - 6 ))
  (( wrap_width < 30 )) && wrap_width=30

  drawn_rows=0   # rows the previous draw printed; used to redraw cleanly

  draw() {
    local rows=0
    printf '   %sChoose which skills to install%s  %s↑/↓ move · space toggle · a all · n none · enter confirm · q quit%s\n' \
      "${BOLD}" "${RESET}" "${DIM}" "${RESET}"
    rows=$((rows + 1))
    hr; rows=$((rows + 1))

    local i=0
    local box pointer
    for name in "${skills[@]}"; do
      if (( selected[i] )); then box="${GREEN}[✓]${RESET}"; else box="${DIM}[ ]${RESET}"; fi
      if (( i == cursor )); then pointer="${CYAN}❯${RESET}"; else pointer=" "; fi
      printf '   %s %s %s\n' "$pointer" "$box" "$name"
      rows=$((rows + 1))
      i=$((i + 1))
    done
    hr; rows=$((rows + 1))

    # Full description for the highlighted skill, soft-wrapped on word boundaries.
    local desc="${descriptions[cursor]}"
    if [[ -n "$desc" ]]; then
      local line
      while IFS= read -r line; do
        printf '   %s%s%s\n' "${DIM}" "$line" "${RESET}"
        rows=$((rows + 1))
      done < <(printf '%s\n' "$desc" | fold -s -w "$wrap_width")
    else
      printf '   %s(no description)%s\n' "${DIM}" "${RESET}"
      rows=$((rows + 1))
    fi

    drawn_rows=$rows
  }

  # Bash 3.2 (macOS default) only accepts integer timeouts for `read -t`.
  # Bash 4+ accepts fractional. Pick the smallest value supported.
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
      $'\033[B'|j) (( cursor < ${#skills[@]} - 1 )) && cursor=$((cursor + 1)) ;;
      ' ')         selected[cursor]=$(( 1 - selected[cursor] )) ;;
      a|A)         for i in "${!selected[@]}"; do selected[i]=1; done ;;
      n|N)         for i in "${!selected[@]}"; do selected[i]=0; done ;;
      ''|$'\n'|$'\r') break ;;
      q|Q)         printf '%s' "${SHOW_CURSOR}"; warn "aborted"; exit 130 ;;
    esac
    # Move cursor up by the rows the previous draw printed, clear to end of
    # screen, redraw. drawn_rows is updated by draw() each call so the count
    # tracks variable-height description blocks.
    printf '\033[%dA\033[J' "$drawn_rows"
    draw
  done
  printf '%s' "${SHOW_CURSOR}"

  only_list=()
  for i in "${!skills[@]}"; do
    (( selected[i] )) && only_list+=("${skills[i]}")
  done
  if [[ ${#only_list[@]} -eq 0 ]]; then
    warn "no skills selected — exiting"
    exit 0
  fi
fi

# ─── prompt for statusline ─────────────────────────────────────────────────────

if (( interactive )) && [[ -z "$statusline_choice" ]] && [[ -f "$STATUSLINE_SRC" ]]; then
  printf '\n'
  printf '   %sInstall the hawk statusline?%s %s(project · branch · context %%)%s\n' \
    "${BOLD}" "${RESET}" "${DIM}" "${RESET}"
  printf '   %swrites ~/.claude/hawk-statusline.sh and updates ~/.claude/settings.json%s\n' \
    "${DIM}" "${RESET}"
  printf '\n   %sinstall? [y/N]>%s ' "${CYAN}" "${RESET}"
  IFS= read -r reply <"$tty_in" || reply=""
  case "$reply" in
    y|Y|yes|YES) statusline_choice="yes" ;;
    *)           statusline_choice="no"  ;;
  esac
  printf '\n'
fi

# ─── install ───────────────────────────────────────────────────────────────────

should_install() {
  local name="$1"
  if [[ ${#only_list[@]} -eq 0 ]]; then return 0; fi
  for picked in "${only_list[@]}"; do
    [[ "$picked" == "$name" ]] && return 0
  done
  return 1
}

if (( dry_run )); then
  step "Planning installation → ${BOLD}${TARGET_DIR}${RESET}"
else
  step "Installing skills → ${BOLD}${TARGET_DIR}${RESET}"
fi
hr

count=0
fresh=0
replaced=0
installed_skill_dirs=()   # absolute paths of SKILL.md dirs this run wrote
for name in "${skills[@]}"; do
  should_install "$name" || continue
  src="$SOURCE_DIR/$name"
  installed_name="${prefix}${name}"
  dest="$TARGET_DIR/${installed_name}"
  existed=0
  [[ -e "$dest" ]] && existed=1

  display="$installed_name"
  if [[ -n "$prefix" ]]; then
    display="${name} ${DIM}→${RESET} ${BOLD}${installed_name}${RESET}"
  fi

  if (( dry_run )); then
    if (( existed )); then
      printf '   %s↻%s %s %s(would replace)%s\n' "${YELLOW}" "${RESET}" "$display" "${DIM}" "${RESET}"
    else
      printf '   %s+%s %s %s(would install)%s\n' "${GREEN}"  "${RESET}" "$display" "${DIM}" "${RESET}"
    fi
  else
    rm -rf "$dest"
    cp -R "$src" "$dest"
    # Rewrite the SKILL.md `name:` field so the slash-command matches the dir.
    if [[ -n "$prefix" && -f "$dest/SKILL.md" ]]; then
      # Cross-platform sed (-i.bak works on macOS BSD sed and GNU sed).
      sed -i.bak -E "s/^name:[[:space:]]*${name}[[:space:]]*$/name: ${installed_name}/" "$dest/SKILL.md"
      rm -f "$dest/SKILL.md.bak"
    fi
    installed_skill_dirs+=("$dest")
    if (( existed )); then
      printf '   %s↻%s %s %s(replaced)%s\n' "${YELLOW}" "${RESET}" "$display" "${DIM}" "${RESET}"
      replaced=$((replaced + 1))
    else
      printf '   %s✓%s %s\n' "${GREEN}" "${RESET}" "$display"
      fresh=$((fresh + 1))
    fi
  fi
  count=$((count + 1))
done

hr

if [[ ${#only_list[@]} -gt 0 && $count -eq 0 ]]; then
  fail "no skills matched filter: ${only_list[*]}"
  exit 1
fi

# ─── agents ────────────────────────────────────────────────────────────────────
# Subagent definitions live at ~/.claude/agents/<name>.md and are referenced
# by skills via Agent(subagent_type="<name>", …). Always installed alongside
# skills — they're tiny and the audit-using skills depend on them.
# When --prefix is set: rewrite each agent's filename + `name:` field, and
# rewrite all agent-name references inside SKILL.md files this run installed
# so the wiring matches.

AGENTS_TARGET="$HOME/.claude/agents"
agents_count=0
agent_names=()

if [[ -d "$AGENTS_SRC" ]]; then
  # Enumerate agent base names. Validate each — `${name}` is interpolated
  # into sed regexes and filenames; lowercase letters/digits/hyphens only.
  for src in "$AGENTS_SRC"/*.md; do
    [[ -f "$src" ]] || continue
    n="$(basename "$src" .md)"
    if [[ ! "$n" =~ ^[a-z0-9-]+$ ]]; then
      fail "agent name '$n' must be lowercase letters/digits/hyphens"
      exit 1
    fi
    agent_names+=("$n")
  done

  if (( ${#agent_names[@]} > 0 )); then
    if (( dry_run )); then
      step "Planning agents → ${BOLD}${AGENTS_TARGET}${RESET}"
      hr
      for name in "${agent_names[@]}"; do
        installed="${prefix}${name}"
        dest="$AGENTS_TARGET/${installed}.md"
        if [[ -e "$dest" ]]; then
          printf '   %s↻%s %s.md %s(would replace)%s\n' "${YELLOW}" "${RESET}" "$installed" "${DIM}" "${RESET}"
        else
          printf '   %s+%s %s.md %s(would install)%s\n' "${GREEN}" "${RESET}" "$installed" "${DIM}" "${RESET}"
        fi
      done
      hr
    else
      mkdir -p "$AGENTS_TARGET"
      step "Installing agents → ${BOLD}${AGENTS_TARGET}${RESET}"
      hr
      for name in "${agent_names[@]}"; do
        src="$AGENTS_SRC/${name}.md"
        installed="${prefix}${name}"
        dest="$AGENTS_TARGET/${installed}.md"
        existed=0
        [[ -e "$dest" ]] && existed=1
        cp "$src" "$dest"
        # Rewrite the agent's `name:` frontmatter field when prefixed.
        if [[ -n "$prefix" ]]; then
          sed -i.bak -E "s/^name:[[:space:]]*${name}[[:space:]]*$/name: ${installed}/" "$dest"
          rm -f "$dest.bak"
        fi
        if (( existed )); then
          printf '   %s↻%s %s.md %s(replaced)%s\n' "${YELLOW}" "${RESET}" "$installed" "${DIM}" "${RESET}"
        else
          printf '   %s✓%s %s.md\n' "${GREEN}" "${RESET}" "$installed"
        fi
        agents_count=$((agents_count + 1))
      done
      hr

      # Rewrite agent-name references inside SKILL.md files THIS RUN installed.
      # Restricted to installed_skill_dirs so we don't touch unrelated user
      # skills or older hawk installs at a different prefix.
      # One sed pass per file with all agent rewrites combined as -e args.
      if [[ -n "$prefix" ]] && (( ${#installed_skill_dirs[@]} > 0 )); then
        sed_args=()
        for name in "${agent_names[@]}"; do
          # Word-bounded match: requires non-word/non-hyphen on each side so we
          # don't rewrite inside longer names (`audit-logic-extra`) or wildcard
          # references in prose (`audit-*`).
          sed_args+=(-e "s/([^a-zA-Z0-9_-])${name}([^a-zA-Z0-9_-])/\1${prefix}${name}\2/g")
        done
        for md_dir in "${installed_skill_dirs[@]}"; do
          md="$md_dir/SKILL.md"
          [[ -f "$md" ]] || continue
          sed -i.bak -E "${sed_args[@]}" "$md"
          rm -f "$md.bak"
        done
      fi
    fi
  fi
fi

# ─── statusline ────────────────────────────────────────────────────────────────

statusline_installed=0
statusline_settings_note=""

install_statusline() {
  local dest="$HOME/.claude/hawk-statusline.sh"
  local settings="$HOME/.claude/settings.json"
  # Bare path; the script's shebang handles execution. Avoids a quoting
  # bug when $HOME contains spaces (e.g. "/Users/Pablo Perez/...").
  local cmd="$dest"
  local ts
  ts="$(date +%s)-$$"   # date+pid: collision-free across rapid reruns

  if [[ ! -f "$STATUSLINE_SRC" ]]; then
    warn "statusline source missing at $STATUSLINE_SRC — skipping"
    return 1
  fi

  if (( dry_run )); then
    if [[ -f "$dest" ]]; then
      printf '   %s↻%s hawk-statusline.sh %s(would replace)%s\n' \
        "${YELLOW}" "${RESET}" "${DIM}" "${RESET}"
    else
      printf '   %s+%s hawk-statusline.sh %s(would install)%s\n' \
        "${GREEN}" "${RESET}" "${DIM}" "${RESET}"
    fi
    if [[ -f "$settings" ]]; then
      printf '   %s↻%s settings.json statusLine %s(would update)%s\n' \
        "${YELLOW}" "${RESET}" "${DIM}" "${RESET}"
    else
      printf '   %s+%s settings.json %s(would create)%s\n' \
        "${GREEN}" "${RESET}" "${DIM}" "${RESET}"
    fi
    statusline_installed=1
    return 0
  fi

  # Back up existing script if it exists and differs from what we ship.
  if [[ -f "$dest" ]] && ! cmp -s "$STATUSLINE_SRC" "$dest"; then
    cp "$dest" "${dest}.bak.${ts}"
  fi
  cp "$STATUSLINE_SRC" "$dest"
  chmod +x "$dest"
  printf '   %s✓%s hawk-statusline.sh %s→ %s%s\n' \
    "${GREEN}" "${RESET}" "${DIM}" "$dest" "${RESET}"

  # Update settings.json. jq is required for in-place edits; without it,
  # we only create from scratch and tell the user to merge by hand.
  if command -v jq >/dev/null 2>&1; then
    # Same-filesystem temp file so the rename is atomic.
    local tmp
    tmp="$(mktemp -- "$HOME/.claude/.settings.XXXXXX")"
    if [[ -f "$settings" ]]; then
      # Merge into any existing .statusLine — preserves user-set siblings
      # like `padding` and `hideVimModeIndicator`.
      if ! jq --arg cmd "$cmd" \
        '.statusLine = (.statusLine // {}) + {type:"command", command:$cmd}' \
        "$settings" >"$tmp" 2>/dev/null; then
        rm -f "$tmp"
        warn "could not parse $settings — leaving it untouched"
        statusline_settings_note="manual: add { \"statusLine\": { \"type\":\"command\", \"command\":\"$cmd\" } }"
        statusline_installed=1
        return 0
      fi
      cp "$settings" "${settings}.bak.${ts}"
      mv "$tmp" "$settings"
      printf '   %s✓%s settings.json statusLine %s(prev backed up)%s\n' \
        "${GREEN}" "${RESET}" "${DIM}" "${RESET}"
    else
      jq -n --arg cmd "$cmd" \
        '{statusLine:{type:"command", command:$cmd}}' >"$settings"
      rm -f "$tmp"
      printf '   %s✓%s settings.json %s(created)%s\n' \
        "${GREEN}" "${RESET}" "${DIM}" "${RESET}"
    fi
  else
    if [[ -f "$settings" ]]; then
      warn "jq not found — settings.json left untouched"
      statusline_settings_note="manual: add { \"statusLine\": { \"type\":\"command\", \"command\":\"$cmd\" } }"
    else
      cat >"$settings" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "$cmd"
  }
}
EOF
      printf '   %s✓%s settings.json %s(created)%s\n' \
        "${GREEN}" "${RESET}" "${DIM}" "${RESET}"
    fi
  fi

  statusline_installed=1
  return 0
}

if [[ "$statusline_choice" == "yes" ]]; then
  printf '\n'
  if (( dry_run )); then
    step "Planning statusline install"
  else
    step "Installing statusline"
  fi
  hr
  install_statusline || true
  hr
fi

# ─── summary ───────────────────────────────────────────────────────────────────

printf '\n'
sl_line=""
if (( statusline_installed )); then
  sl_line="${BOLD}Statusline${RESET}  ${DIM}~/.claude/hawk-statusline.sh${RESET}"
fi

if (( dry_run )); then
  if [[ -n "$sl_line" ]]; then
    boxed \
      "${BOLD}Dry-run complete${RESET}" \
      "${DIM}$count skill(s) would be installed${RESET}" \
      "" \
      "$sl_line"
  else
    boxed \
      "${BOLD}Dry-run complete${RESET}" \
      "${DIM}$count skill(s) would be installed${RESET}"
  fi
else
  lines=(
    "${GREEN}✓${RESET} ${BOLD}Installed $count skill(s)${RESET}  ${DIM}($fresh new · $replaced replaced)${RESET}"
    ""
    "${BOLD}Try${RESET}   ${CYAN}/${prefix}coding-process${RESET}  ${CYAN}/${prefix}plan-small${RESET}  ${CYAN}/${prefix}code-audit${RESET}"
    "${BOLD}Read${RESET}  ${DIM}~/.claude/skills/${prefix}<name>/SKILL.md${RESET}"
    "${BOLD}Docs${RESET}  ${DIM}https://github.com/${REPO}${RESET}"
  )
  if [[ -n "$sl_line" ]]; then
    lines+=("" "$sl_line")
  fi
  boxed "${lines[@]}"
  if [[ -n "$statusline_settings_note" ]]; then
    printf '\n'
    warn "$statusline_settings_note"
  fi
fi
printf '\n'
