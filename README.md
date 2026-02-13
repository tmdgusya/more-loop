# more-loop

[한국어](README_ko.md)

Iterative development script that wraps the `claude` CLI in a while loop.

## How it works

1. **Bootstrap** — Claude reads a spec file and generates `acceptance.md` (definition of done) and `tasks.md` (atomic implementation steps) as `- [ ]` checklists
2. **Loop** — Each iteration: pick one task, implement it, verify. If verification fails, revert and retry next iteration.
3. **Improve** — If all tasks finish before N iterations, Claude picks improvements (refactor, tests, etc.)

Each iteration is a fresh `claude -p` process with `--permission-mode bypassPermissions`. State is passed via files in `.more-loop/<run-name>/`.

## Walkthrough: Complete Workflow

Let's walk through building a simple calculator API to see how more-loop works in practice.

### Step 1: Create your spec

```bash
# Use the interactive wizard to create a spec file
/more-loop-prompt calculator-api
```

Answer the questions:
- **What to build?** → "A REST API for a calculator"
- **Tech stack?** → "Python, FastAPI, pytest"
- **Key features?** → "add, subtract, multiply, divide endpoints"

This creates `.more-loop/runs/calculator-api/prompt.md`

### Step 2: (Optional) Create a verification plan

```bash
# Use the interactive wizard to create verification
/more-loop-verify calculator-api
```

Define how to verify correctness:
- **Tests pass?** → `pytest tests/ -v`
- **API works?** → `curl http://localhost:8000/calculate`
- **Type checks?** → `mypy .`

This creates `.more-loop/runs/calculator-api/verify.sh`

### Step 3: Run with Oracle (recommended!)

```bash
# The --oracle flag enables Test-First Architect
more-loop --oracle -n 10 calculator-api verify.sh
```

**What happens next:**

#### Phase 1: Bootstrap
- Claude reads `prompt.md`
- Creates `acceptance.md` (definition of done)
- Creates `tasks.md` (implementation steps)
- Example tasks:
  ```
  - [ ] Set up FastAPI project structure
  - [ ] Implement /calculate endpoint
  - [ ] Add add, subtract, multiply, divide operations
  - [ ] Add input validation
  - [ ] Write unit tests
  ```

#### Phase 2: Oracle (NEW!)
- Claude acts as **Test-First Architect**
- Guides you through 5 levels:

**Level 1: Syntax (Does it run?)**
```
Oracle: "What build commands should pass?"
You: "pytest tests/ should pass and mypy . should succeed"

Oracle: "What type checking?"
You: "Python 3.11+ with strict mode"

Oracle: "Any linting?"
You: "ruff check . with zero warnings"
```

**Level 2: I/O (Does it work?)**
```
Oracle: "What are your core functions?"
You: "add(a, b) returns sum, divide(a, b) returns quotient or raises error"

Oracle: "What about edge cases?"
You: "divide by zero raises ZeroDivisionError, divide by negative numbers works"
```

**Level 3: Property (What invariants hold?)**
```
Oracle: "What mathematical properties?"
You: "For all a, b: add(a, b) == add(b, a) (commutative)"
```

**Level 4: Formal (Business rules)**
```
Oracle: "What are your business constraints?"
You: "Results are always finite numbers (no NaN or Infinity)"
```

**Level 5: Semantic (User intent)**
```
Oracle: "What are your user scenarios?"
You: "Given valid numbers, when user sends POST /calculate with operation='add',
       then they get the sum within 100ms"
```

- Oracle creates `test-guide.md` with all your criteria
- This becomes your "answer key" for implementation!

#### Phase 3: Task Iterations

Now each iteration gets your Test Guide as context:

```bash
Iteration 1: "Set up FastAPI project structure"
```

Claude sees:
```
## Test Guide (Oracle output):
### Level 1: Syntax
- [ ] pytest tests/ passes
- [ ] mypy . passes

### Level 2: I/O
- [ ] add(a, b) returns sum
...
```

So Claude **knows** to:
- Create `pyproject.toml` with pytest config
- Add `mypy` configuration
- Set up project structure

```bash
Iteration 2: "Implement /calculate endpoint"
```

Claude sees the Test Guide and knows:
- Must accept POST requests
- Must validate inputs
- Must return JSON results
- Must handle division by zero

#### Phase 4: Audit (when all tasks done)

Once all tasks are checked off, Claude reviews the **actual code**:
- Reads implementation files
- Rates each task: SOLID / WEAK / INCOMPLETE
- Identifies specific issues

#### Phase 5: Improve (remaining iterations)

Claude fixes issues found in audit:
- "Found: No error handling for negative numbers in multiply()"
- "Fixed: Added validation and proper error messages"

### Step 4: Check your results

After completion, inspect `.more-loop/runs/calculator-api/`:

```bash
.more-loop/runs/calculator-api/
├── prompt.md           # Your original spec
├── acceptance.md       # Definition of done (all checked ✓)
├── tasks.md            # Implementation steps (all checked ✓)
├── test-guide.md       # Your Test Guide from Oracle
├── iterations/
│   ├── 0-bootstrap.md
│   ├── 1.md             # Task 1 implementation
│   ├── 1-verify.md     # Verification result
│   ├── 2.md             # Task 2 implementation
│   ...
│   └── audit.md         # Audit findings
└── state.json          # Full state history
```

### Key Benefits of Using Oracle

**Without Oracle:**
- "Hope the code is good"
- Discover issues during testing (too late!)
- Vague acceptance criteria

**With Oracle:**
- "Here's exactly what 'correct' means"
- Claude knows requirements before coding
- Concrete testable criteria for every level
- Your Test Guide becomes documentation

### Pro Tips

1. **Always use `--oracle`** for new projects - it saves time!
2. **Be specific** in Oracle - vague criteria get rejected
3. **Use `--approve`** - review the plan before implementation starts
4. **Check `test-guide.md`** after Oracle completes - this is your spec!
5. **Create verify.sh** - automated tests catch regressions

### Resume if interrupted

```bash
# If Ctrl+C or error stops you
more-loop --resume .more-loop/calculator-api -n 5 verify.sh
```

Bootstrap is skipped, iterations continue from where you left off!

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

## Multi-Provider Parallel Mode

Run the same spec across multiple AI providers simultaneously using `multi-loop`:

### Quick start

```bash
# Run GLM, Kimi, and Claude in parallel
multi-loop -n 10 -w prompt.md verify.sh

# Run specific providers only
multi-loop --providers glm,claude -n 8 prompt.md

# Check status (from phone or another terminal)
multi-loop --status

# Stop all providers
multi-loop --stop
```

### Provider config (`providers.json`)

Providers are defined in a JSON config file. Each provider specifies:

- `command` — CLI command template with `{args}`, `{prompt}`, `{verify}` placeholders
- `env` — Environment variables to set before launch
- `unset` — Environment variables to unset
- `setup` — Shell command to run before launch (e.g., `source ~/.opencode/env.sh`)

```bash
# Generate default config
multi-loop --init

# Use custom config
multi-loop --config my-providers.json -n 5 prompt.md
```

### Adding a custom provider

Edit `providers.json`:

```json
{
  "providers": {
    "my-agent": {
      "command": "my-cli --auto {prompt}",
      "env": { "MY_API_KEY": "..." },
      "setup": "source ~/.my-agent/env.sh"
    }
  }
}
```

Config search order: `--config` flag > `./multi-loop.json` > `./providers.json` > `~/.config/multi-loop/providers.json`

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
├── multi-loop                         # Multi-provider parallel runner (tmux)
├── providers.json                     # Provider config (env vars, commands)
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
│   ├── test-oracle-integration.sh     # Oracle feature test
│   └── test-multi-loop.sh            # Multi-loop orchestrator tests
├── CLAUDE.md                          # Project instructions for Claude Code
├── README.md                          # This file
└── README_ko.md                       # Korean documentation
```

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude` on PATH)
- Bash 4+
