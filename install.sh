#!/usr/bin/env bash
set -euo pipefail

# install.sh — Install more-loop binary and Claude Code skills

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
SKILLS_DIR="${HOME}/.claude/skills"

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

  # Binary
  mkdir -p "$BIN_DIR"
  cp "$SCRIPT_DIR/more-loop" "$BIN_DIR/more-loop"
  chmod +x "$BIN_DIR/more-loop"
  echo "  Installed $BIN_DIR/more-loop"

  # Skills
  mkdir -p "$SKILLS_DIR/more-loop-prompt"
  mkdir -p "$SKILLS_DIR/more-loop-verify"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-prompt/SKILL.md" "$SKILLS_DIR/more-loop-prompt/SKILL.md"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-verify/SKILL.md" "$SKILLS_DIR/more-loop-verify/SKILL.md"
  echo "  Installed skills to $SKILLS_DIR/"

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
  echo "  Removed skills from $SKILLS_DIR/"

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
