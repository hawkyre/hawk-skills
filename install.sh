#!/usr/bin/env bash
# Install hawk-skills into ~/.claude/skills/.
# One-shot: existing skills with the same name are replaced.
#
# Usage:
#   ./install.sh                  # install all skills
#   ./install.sh --dry-run        # show what would happen, no changes
#   ./install.sh --only code-audit --only fix-bug
#                                 # install only the named skills (repeatable)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

dry_run=0
only_list=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    --only)
      if [[ $# -lt 2 ]]; then
        echo "error: --only requires a skill name" >&2
        exit 2
      fi
      only_list+=("$2")
      shift 2
      ;;
    -h|--help)
      sed -n '2,11p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "error: source dir not found: $SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -d "$HOME/.claude" ]]; then
  echo "error: $HOME/.claude does not exist (is Claude Code installed?)" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

should_install() {
  local name="$1"
  if [[ ${#only_list[@]} -eq 0 ]]; then
    return 0
  fi
  for picked in "${only_list[@]}"; do
    [[ "$picked" == "$name" ]] && return 0
  done
  return 1
}

count=0
for src in "$SOURCE_DIR"/*/; do
  name="$(basename "$src")"
  should_install "$name" || continue

  dest="$TARGET_DIR/$name"
  if (( dry_run )); then
    if [[ -e "$dest" ]]; then
      echo "would replace: $dest"
    else
      echo "would install: $dest"
    fi
  else
    rm -rf "$dest"
    cp -R "$src" "$dest"
    echo "installed: $name"
  fi
  count=$((count + 1))
done

if [[ ${#only_list[@]} -gt 0 && $count -eq 0 ]]; then
  echo "error: no skills matched --only filter: ${only_list[*]}" >&2
  exit 1
fi

if (( dry_run )); then
  echo "dry-run complete: $count skill(s) would be installed"
else
  echo "done: $count skill(s) installed into $TARGET_DIR"
fi
