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
- `system-prompts/` — Phase-specific system prompts injected via `--append-system-prompt`
  - `bootstrap.md` — Controls task count and granularity during bootstrap
  - `oracle.md` — Test-First Architect phase for creating Test Guides
  - `task.md` — Enforces single-task-per-iteration protocol
  - `improve.md` — Guides improvement mode behavior
- `.claude/skills/more-loop-prompt/SKILL.md` — Skill: create prompt files
- `.claude/skills/more-loop-verify/SKILL.md` — Skill: create verification files
- `README.md` — Full documentation
- `CLAUDE.md` — This file

## more-loop Architecture Notes

- `system-prompts/` — phase-specific prompts injected via `--append-system-prompt`
  - `bootstrap.md` — Controls task count and granularity during bootstrap
  - `oracle.md` — Test-First Architect phase for creating Test Guides
  - `task.md` — Enforces single-task-per-iteration protocol
  - `improve.md` — Guides improvement mode behavior
- `enforce_single_task()` allows up to 3 tasks per iteration (configurable via `max_per_iter`)
- `enforce_max_tasks` in bootstrap truncates task list if Claude exceeds limit
- Verify for `.md` files should only evaluate items relevant to the current iteration's task
- Default model: opus
- `--resume` flag skips bootstrap and continues from last completed iteration
- `--oracle` flag enables Test-First Architect phase before task iterations
- `test-guide.md` — Oracle output file containing 5-level test criteria used as context during iterations
