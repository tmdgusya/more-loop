---
name: more-loop-verify
description: Create a verification file (shell script or markdown checklist) for use with the more-loop iterative development script
disable-model-invocation: true
argument-hint: "[run-name]"
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion, Bash
---

# Create a more-loop verification file

You are helping the user create a **verification file** for use with `more-loop`, an iterative development script that wraps the `claude` CLI.

## How more-loop uses verification files

Verification runs at two points with different roles:

1. **During task iterations** — verify runs after each task as **informational feedback**. Results are logged and passed to the next iteration, but failures do NOT roll back task completion. Tasks always progress forward.
2. **After all tasks complete** — verify becomes a **gate**. If it fails, more-loop enters "fix mode" where Claude sees the failure details and iterates on fixes until verify passes or iterations run out.

- **Shell script (`.sh`)**: Executed with `bash` in a separate process group. Exit code 0 = PASS, non-zero = FAIL. Stdout/stderr is captured as feedback.
- **Markdown (`.md`)**: Fed to a fresh `claude -p` process that evaluates the checklist against the current codebase state and outputs PASS or FAIL with reasoning.

Since `.sh` verify files are the **final acceptance gate**, they should be comprehensive and test the complete deliverable.

## Your process

1. **Ask the user** which verification type they want:

   - **Shell script (`.sh`)** — Best for: tests passing, files existing, builds succeeding, linting, concrete measurable checks. Fast and deterministic.
   - **Markdown checklist (`.md`)** — Best for: code quality, architecture decisions, subjective criteria, checking things that are hard to script. Uses an LLM call so slower and costs tokens.

   If `$ARGUMENTS` is provided and ends in `.sh` or `.md`, infer the type from the extension.

2. **Ask what should be verified** — what does "done" look like? Ask about:
   - Build/compile success?
   - Tests passing? Which test command?
   - Specific files or functions that must exist?
   - Linting or formatting?
   - Runtime behavior checks?
   - Code quality or architectural constraints?

   Ask at most 2 rounds of clarifying questions.

3. **Scan the codebase** if relevant — find existing test commands, build scripts, linters, CI config to build on what's already there.

4. **Write the verification file** using the appropriate format below.

## Shell script format (`.sh`)

Write a bash script that:
- Starts with `#!/usr/bin/env bash` and `set -euo pipefail`
- Runs checks sequentially — first failure stops and exits non-zero
- Prints clear messages about what is being checked
- Prints a reason on failure (captured by more-loop as feedback)
- Exits 0 only if everything passes

Template:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Checking build ==="
<build command>

echo "=== Checking tests ==="
<test command>

echo "=== Checking lint ==="
<lint command>

echo "=== All checks passed ==="
```

Guidelines:
- Prefer existing project commands (`npm test`, `make check`, `pytest`, etc.)
- Include a syntax/build check before running tests
- Keep it reasonably fast — verification runs after every iteration and as the final gate
- Don't check things that are subjective or hard to automate — use a `.md` file for those

## Markdown checklist format (`.md`)

Write a markdown file with `- [ ]` checklist items that Claude can evaluate by examining the codebase.

Template:

```markdown
# Verification Checklist

## Functionality
- [ ] <Specific, evaluable criterion>
- [ ] <Another criterion>

## Code Quality
- [ ] <Quality criterion>

## Tests
- [ ] <Test criterion>
```

Guidelines:
- Each item must be **concretely evaluable** — Claude needs to determine pass/fail by reading code
- Bad: "Code is clean" (too vague)
- Good: "All public functions have error handling for invalid inputs"
- Bad: "Tests exist" (too vague)
- Good: "There are tests for the login endpoint covering success and invalid credentials"
- Keep to 5-10 items — more items = slower + more expensive verification
- Order from most critical to least critical

## Output path

Files are organized under `.more-loop/runs/<run-name>/`:

1. **Determine the run name**: Use `$ARGUMENTS` if provided (as a slug, e.g., `web-dashboard`). Otherwise, derive a short kebab-case slug from what the user described, or ask the user. If a `.more-loop/runs/<run-name>/prompt.md` already exists for a matching topic, use the same `<run-name>` directory so the prompt and verify files live together.
2. **Create the directory** if it doesn't exist: `.more-loop/runs/<run-name>/`
3. **Write the file**: `.more-loop/runs/<run-name>/verify.sh` (or `verify.md` for markdown type)

If `$ARGUMENTS` looks like an explicit file path (contains `/` or ends in `.sh`/`.md`), respect it as-is instead of using the directory convention.

If writing a `.sh` file, make it executable (`chmod +x`).

## Test quality principles

### Test priority hierarchy (Shell scripts)

Write tests at the highest behavioral level possible. Avoid keyword-grep-only tests.

**Level 1 — Behavioral (preferred)**: Execute the actual program, observe runtime behavior.
```bash
# Good: Actually start the server and test it
python3 server.py "$RUN_DIR" --port "$PORT" &
curl -sf http://127.0.0.1:$PORT/state.json | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'phase' in d"
```

**Level 2 — Structural**: Verify code structure (function exists, is called, correct arguments).
```bash
# Good: Verify function is defined AND called
grep -q '^write_state_json()' script.sh
grep -c 'write_state_json ' script.sh  # count call sites
```

**Level 3 — Keyword grep (last resort)**: Only when behavioral/structural tests are impractical.
```bash
# Bad: grep "approve" script.sh  (matches comments, strings, anything)
# Better: grep -q 'APPROVE_SIGNAL' script.sh  (specific constant name)
```

### Verify actual interfaces before writing tests

Never assume how a program is invoked based on the spec. Always check the real interface first:

- For Python scripts: read the `argparse` block or run `python3 script.py --help`
- For bash scripts: read the `usage()` function or run `bash script.sh --help`
- For config files: read the actual file format

```bash
# Bad — assumes flags from spec wording:
python3 server.py --run-dir "$DIR" --dashboard "$HTML"

# Good — matches actual argparse definition:
python3 server.py "$DIR" --port "$PORT"
```

### Spec coverage tracking

Include a coverage comment block at the top of each verification file that maps spec requirements to test status:

```bash
# Spec coverage:
#   [TESTED] Web server serves dashboard HTML — Section 6
#   [TESTED] POST /approve creates signal file — Section 6
#   [GREP]   State JSON has required fields — Section 5 (structural check only)
#   [GAP]    Approval timeout countdown display — not tested
```

Use `[TESTED]` for behavioral tests, `[GREP]` for keyword/structural checks, `[GAP]` for untested requirements.

### Negative tests

Always include tests for opt-in features being inactive by default and error paths:

```bash
# Opt-in feature disabled when flag absent:
check "no state.json without --web" bash -c "! test -f \"\$RUN_DIR/state.json\""

# Error message on bad input:
check "error on missing file" bash -c "bash script.sh --web nonexistent 2>&1 | grep -qi 'error\\|not found'"

# Edge case handling:
check "timeout 0 means infinite wait" grep -q 'timeout.*0\|infinite\|forever' script.sh
```

### When to use `.sh` vs `.md`

**Shell script (`.sh`)** — things that can be automated:
- Runtime behavior (start server, hit endpoints, check responses)
- File existence and syntax validation
- Concrete value verification (port numbers, field names, exit codes)
- Signal file creation and cleanup

**Markdown checklist (`.md`)** — things that need human/LLM judgment:
- Architecture decisions ("state.json is the ONLY interface between bash and server")
- Code quality ("no duplicated logic between X and Y")
- Control flow tracing ("write_state_json is called at every phase transition")
- Design patterns ("error handling uses a consistent approach")

**Do NOT put in `.md`**:
- Runtime behavior assertions ("server responds with 200") — use `.sh`
- Automatable checks ("file has fewer than 150 lines") — use `.sh`
- Anything you could verify with `curl`, `grep`, or `python3 -c` — use `.sh`

**Cross-referencing**: When both files exist, the `.md` file should note which items are already verified by `.sh` and focus on what `.sh` cannot check. Use phrasing like "Verified by shell script; this item checks the *design rationale*."

### Markdown checklist best practices (supplement)

In addition to the guidelines above:

- **Name the target**: Each item should specify the file, function, or code region being checked.
  - Bad: "Error handling exists"
  - Good: "In `server.py`, the `DashboardHandler._serve_state` method returns a JSON error response (not a bare 500) when `state.json` is missing"

- **Use "code contains" phrasing**: Write items as falsifiable statements about code existence, not runtime behavior claims.
  - Bad: "The server binds to localhost only"
  - Good: "In `server.py`, `HTTPServer` is instantiated with `'127.0.0.1'` as the bind address (not `''` or `'0.0.0.0'`)"

- **Must be falsifiable**: Every item must be answerable as true/false by reading the code. If an item requires running the program to evaluate, move it to `.sh`.
