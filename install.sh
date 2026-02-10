#!/usr/bin/env bash
set -euo pipefail

# install.sh — Install more-loop binary and Claude Code skills

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SKILLS_DIR="${HOME}/.claude/skills"
DATA_DIR="${HOME}/.local/share/more-loop"

usage() {
  cat <<'EOF'
Usage: install.sh [--uninstall]

Install:
  ./install.sh            Copy more-loop to ~/.local/bin/ and skills to ~/.claude/skills/

Uninstall:
  ./install.sh --uninstall  Remove installed files
EOF
}

install() {
  echo "Installing more-loop..."

  # Binary — remove first to handle existing symlinks from `make link`
  mkdir -p "$BIN_DIR"
  rm -f "$BIN_DIR/more-loop"
  cp "$SCRIPT_DIR/more-loop" "$BIN_DIR/more-loop"
  chmod +x "$BIN_DIR/more-loop"
  echo "  Installed $BIN_DIR/more-loop"

  # Skills — remove first to handle existing symlinks
  mkdir -p "$SKILLS_DIR/more-loop-prompt"
  mkdir -p "$SKILLS_DIR/more-loop-verify"
  mkdir -p "$SKILLS_DIR/more-loop-oracle"
  rm -f "$SKILLS_DIR/more-loop-prompt/SKILL.md" "$SKILLS_DIR/more-loop-verify/SKILL.md" "$SKILLS_DIR/more-loop-oracle/SKILL.md"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-prompt/SKILL.md" "$SKILLS_DIR/more-loop-prompt/SKILL.md"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-verify/SKILL.md" "$SKILLS_DIR/more-loop-verify/SKILL.md"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-oracle/SKILL.md" "$SKILLS_DIR/more-loop-oracle/SKILL.md"
  echo "  Installed skills to $SKILLS_DIR/"

  # System prompts — remove first to handle existing symlinks
  mkdir -p "$DATA_DIR/system-prompts"
  rm -f "$DATA_DIR"/system-prompts/*.md 2>/dev/null || true
  for f in "$SCRIPT_DIR"/system-prompts/*.md; do
    [[ -f "$f" ]] && cp "$f" "$DATA_DIR/system-prompts/"
  done
  echo "  Installed system prompts to $DATA_DIR/system-prompts/"

  # Web dashboard files — remove first to handle existing symlinks
  mkdir -p "$DATA_DIR"
  if [[ -f "$SCRIPT_DIR/server.py" ]]; then
    rm -f "$DATA_DIR/server.py"
    cp "$SCRIPT_DIR/server.py" "$DATA_DIR/server.py"
    echo "  Installed $DATA_DIR/server.py"
  fi
  if [[ -f "$SCRIPT_DIR/dashboard.html" ]]; then
    rm -f "$DATA_DIR/dashboard.html"
    cp "$SCRIPT_DIR/dashboard.html" "$DATA_DIR/dashboard.html"
    echo "  Installed $DATA_DIR/dashboard.html"
  fi

  # PATH check
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo ""
    echo "WARNING: $BIN_DIR is not on your PATH."
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
  fi

  echo "Done."
}

uninstall() {
  echo "Uninstalling more-loop..."

  rm -f "$BIN_DIR/more-loop"
  echo "  Removed $BIN_DIR/more-loop"

  rm -rf "$SKILLS_DIR/more-loop-prompt"
  rm -rf "$SKILLS_DIR/more-loop-verify"
  rm -rf "$SKILLS_DIR/more-loop-oracle"
  echo "  Removed skills from $SKILLS_DIR/"

  rm -rf "$DATA_DIR"
  echo "  Removed web dashboard files from $DATA_DIR/"

  echo "Done."
}

case "${1:-}" in
  --uninstall)
    uninstall
    ;;
  --help|-h)
    usage
    ;;
  "")
    install
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
esac
