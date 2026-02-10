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
more-loop --resume <run-dir> [OPTIONS]
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
| `-m, --model MODEL` | opus | Model to use |
| `--max-tasks N` | auto | Max tasks in bootstrap (default: same as iterations, clamped to <= iterations) |
| `-v, --verbose` | off | Show full claude output |
| `-w, --web` | off | Start web dashboard server |
| `-a, --approve` | off | Enable approval mode (pause after each iteration) |
| `--approve-timeout N` | 180 | Approval timeout in seconds (0 = infinite) |
| `--port PORT` | auto | Web server port |
| `--resume DIR` | | Resume an interrupted run from its run directory |
| `--oracle` | off | Enable Oracle Test-First Architect phase before iterations |
| `-h, --help` | | Show help |

### Examples

```bash
# Basic: 5 iterations with default model (opus)
more-loop prompt.md

# With shell script verification
more-loop prompt.md verify.sh

# With markdown verification and custom settings
more-loop -n 10 -m sonnet prompt.md verify.md

# Limit task count (leave room for retries)
more-loop -n 8 --max-tasks 6 prompt.md verify.sh

# Verbose output
more-loop -v prompt.md verify.sh

# Resume an interrupted run
more-loop --resume .more-loop/my-project -n 8 -v
```

## Resuming interrupted runs

If a run is interrupted (Ctrl+C, error, etc.), you can resume from where it left off:

```bash
# Check existing run directories
ls .more-loop/

# Resume — skips bootstrap, runs 10 MORE iterations from where it left off
more-loop --resume .more-loop/my-project -n 10

# Resume with verify file
more-loop --resume .more-loop/my-project -n 10 verify.sh
```

When resuming, `-n` means **additional iterations** (not total). So `-n 10` runs 10 more iterations from where the previous run stopped.

`--resume` reads `tasks.md`, `acceptance.md`, and `iterations/*.md` from the run directory to determine progress. Options like `-n`, `-m`, `-v` can be changed on resume.

## Bundled skills

This repo includes three Claude Code skills for creating more-loop input files:

- **`/more-loop-prompt`** — Interactive wizard to create a `prompt.md` spec file
- **`/more-loop-verify`** — Interactive wizard to create a `verify.sh` or `verify.md` verification file
- **`/more-loop-oracle`** — Interactive Test-First Architect to create comprehensive Test Guides

Skills are auto-discovered when working in the repo directory. After running `./install.sh` or `make install`, they're available globally.

## Oracle: Test-First Architect Phase

The `--oracle` flag enables a pre-implementation phase that helps you define comprehensive test criteria BEFORE writing any code. This follows the Test-First Architect pattern:

### What the Oracle does

1. **Guides you through 5 Oracle levels** — Syntax, I/O, Property, Formal, Semantic
2. **Asks specific questions** — Builds a Test Guide with testable criteria
3. **Creates `test-guide.md`** — This file is used during task iterations as context
4. **Ensures completeness** — Won't finish until all levels have sufficient criteria

### The 5 Oracle Levels

| Level | Question | Example |
|-------|----------|---------|
| Lv.1: Syntax | Does it run? | "Build passes, type checking succeeds" |
| Lv.2: I/O | Does it work? | "add(5, 3) returns 8, POST /users returns 201" |
| Lv.3: Property | What invariants hold? | "For all a, b: add(a, b) == add(b, a)" |
| Lv.4: Formal | What are business rules? | "Account balance is never negative" |
| Lv.5: Semantic | Does it meet user intent? | "Given logged-in user, when they logout, then they see login page" |

### Example usage

```bash
# With Oracle phase
more-loop --oracle prompt.md verify.sh

# With Oracle + approval mode
more-loop --oracle --approve prompt.md verify.sh
```

See `docs/test-guide-example.md` for a complete Test Guide example.

## LLM behavior control

more-loop uses a multi-layer defense to control LLM behavior:

| Layer | Mechanism | Description |
|-------|-----------|-------------|
| System prompt | `--append-system-prompt` | Per-phase instructions injected to enforce "one task only" |
| Code enforcement | `enforce_single_task()` | Snapshot comparison, deterministically reverts excess tasks |
| Bootstrap cap | `enforce_max_tasks` | Truncates task list if Claude exceeds the limit |

System prompts live in `system-prompts/` and are separated by phase:

- **`bootstrap.md`** — Task count and granularity control
- **`task.md`** — Single-task protocol enforcement, encourages skill/subagent usage
- **`improve.md`** — Improvement mode guidance

## Stopping mid-loop

Press `Ctrl+C` to stop. You may need to press it twice — once to kill the current `claude` subprocess and once to kill the outer loop.

From another terminal you can also run:

```bash
pkill -f more-loop
```

Progress from completed iterations is preserved. The in-progress iteration may be partially applied — check `git status` and `git log` after stopping. Use `--resume` to continue from where you left off.

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
│   ├── oracle.md                      # Test-First Architect phase
│   ├── task.md                        # Single-task-per-iteration enforcement
│   ├── improve.md                     # Improvement mode guidance
│   └── audit.md                       # Code audit protocol
├── .claude/
│   └── skills/
│       ├── more-loop-prompt/SKILL.md  # Prompt creation skill
│       ├── more-loop-verify/SKILL.md  # Verify file creation skill
│       └── more-loop-oracle/SKILL.md  # Test Guide creation skill
├── docs/
│   ├── plans/                         # Implementation plans
│   └── test-guide-example.md          # Example Test Guide
├── tests/                             # Integration tests
│   └── test-oracle-integration.sh     # Oracle feature test
├── CLAUDE.md                          # Project instructions for Claude Code
├── README.md                          # This file
└── README_ko.md                       # Korean documentation
```

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` on PATH)
- Bash 4+
