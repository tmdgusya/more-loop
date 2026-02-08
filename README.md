# more-loop

[한국어](README_ko.md)

Iterative development script that wraps the `claude` CLI in a while loop.

## How it works

1. **Bootstrap** — Claude reads a spec file and generates `acceptance.md` (definition of done) and `tasks.md` (atomic implementation steps) as `- [ ]` checklists
2. **Loop** — Each iteration: pick one task, implement it, verify. If verification fails, revert and retry next iteration.
3. **Improve** — If all tasks finish before N iterations, Claude picks improvements (refactor, tests, etc.)

Each iteration is a fresh `claude -p` process with `--permission-mode bypassPermissions`. State is passed via files in `.more-loop/<run-name>/`.

## Quick start

```bash
# Clone the repo
git clone <repo-url> && cd more-loop

# Run directly from the repo
./more-loop prompt.md

# Or install globally
./install.sh
more-loop prompt.md
```

## Installation

### Project-local (no install needed)

Clone the repo and run `./more-loop` directly. Skills are auto-discovered by Claude Code when working in the repo directory.

### install.sh

```bash
./install.sh              # Install to ~/.local/bin/ + skills to ~/.claude/skills/
./install.sh --uninstall  # Remove installed files
```

### Makefile

```bash
make install    # Copy binary + skills
make uninstall  # Remove installed files
make link       # Symlink instead of copy (for development)
make unlink     # Remove symlinks
make help       # Show all targets
```

Override the install prefix: `make install PREFIX=/usr/local`

## Usage

```
more-loop [OPTIONS] <prompt-file> [verify-file]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `prompt-file` | Spec/prompt describing what to build (required) |
| `verify-file` | Verification plan — `.sh` script or `.md` checklist (optional) |

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `-n, --iterations N` | 5 | Max iterations |
| `-m, --model MODEL` | sonnet | Model to use |
| `--max-tasks N` | auto | Max tasks in bootstrap (auto = iterations\*2, clamped 5-30) |
| `-v, --verbose` | off | Show full claude output |
| `-h, --help` | | Show help |

### Examples

```bash
# Basic: 5 iterations with default model
more-loop prompt.md

# With shell script verification
more-loop prompt.md verify.sh

# With markdown verification and custom settings
more-loop -n 10 -m opus prompt.md verify.md

# Verbose output
more-loop -v prompt.md verify.sh
```

## Bundled skills

This repo includes two Claude Code skills for creating more-loop input files:

- **`/more-loop-prompt`** — Interactive wizard to create a `prompt.md` spec file
- **`/more-loop-verify`** — Interactive wizard to create a `verify.sh` or `verify.md` verification file

Skills are auto-discovered when working in the repo directory. After running `./install.sh` or `make install`, they're available globally.

## Stopping mid-loop

Press `Ctrl+C` to stop. You may need to press it twice — once to kill the current `claude` subprocess and once to kill the outer loop.

From another terminal you can also run:

```bash
pkill -f more-loop
```

Progress from completed iterations is preserved. The in-progress iteration may be partially applied — check `git status` and `git log` after stopping.

## Verification types

| Type | Extension | How it works | Best for |
|------|-----------|--------------|----------|
| Shell script | `.sh` | Runs with bash, exit 0 = pass | Tests, builds, linting, concrete checks |
| Markdown | `.md` | Claude evaluates checklist against codebase | Code quality, architecture, subjective criteria |

## Project structure

```
more-loop
├── more-loop                          # Main executable
├── install.sh                         # Install/uninstall script
├── Makefile                           # Make targets for install/link
├── system-prompts/                    # Phase-specific LLM behavior control
│   ├── bootstrap.md                   # Task count/granularity constraints
│   ├── task.md                        # Single-task-per-iteration enforcement
│   └── improve.md                     # Improvement mode guidance
├── .claude/
│   └── skills/
│       ├── more-loop-prompt/SKILL.md  # Prompt creation skill
│       └── more-loop-verify/SKILL.md  # Verify file creation skill
├── CLAUDE.md                          # Project instructions for Claude Code
└── README.md                          # This file
```

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` on PATH)
- Bash 4+
