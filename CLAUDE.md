# more-loop

Iterative development script that wraps the `claude` CLI in a while loop.

## How it works

1. **Bootstrap** — Claude reads a spec file and generates `acceptance.md` (definition of done) and `tasks.md` (atomic implementation steps) as `- [ ]` checklists
2. **Loop** — Each iteration: pick one task → implement it → verify → if fail, retry next iteration
3. **Improve** — If all tasks finish before N iterations, Claude picks improvements (refactor, tests, etc.)

Each iteration is a fresh `claude -p` process with `--permission-mode bypassPermissions`. State is passed via files in `.more-loop/<run-name>/`.

## Usage

```
./more-loop [OPTIONS] <prompt-file> [verify-file]
```

## Installation

```bash
./install.sh              # Install to ~/.local/bin/ + skills to ~/.claude/skills/
./install.sh --uninstall  # Remove installed files
make link                 # Symlink for development (edits reflected immediately)
```

## Project structure

- `more-loop` — Main executable bash script
- `install.sh` — Install/uninstall script
- `Makefile` — Make targets for install/link/uninstall
- `.claude/skills/more-loop-prompt/SKILL.md` — Skill: create prompt files
- `.claude/skills/more-loop-verify/SKILL.md` — Skill: create verification files
- `README.md` — Full documentation
- `CLAUDE.md` — This file
