---
name: more-loop-verify
description: Create a verification file (shell script or markdown checklist) for use with the more-loop iterative development script
disable-model-invocation: true
argument-hint: "[output-filename]"
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion, Bash
---

# Create a more-loop verification file

You are helping the user create a **verification file** for use with `more-loop`, an iterative development script that wraps the `claude` CLI.

## How more-loop uses verification files

After each task iteration, more-loop runs the verification file to check if the task was completed correctly:

- **Shell script (`.sh`)**: Executed with `bash`. Exit code 0 = PASS, non-zero = FAIL. Stdout/stderr is captured as feedback.
- **Markdown (`.md`)**: Fed to a fresh `claude -p` process that evaluates the checklist against the current codebase state and outputs PASS or FAIL with reasoning.

If verification **fails**, more-loop reverts the task checkbox and retries on the next iteration with the failure feedback appended.

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
- Keep it fast — verification runs after every iteration
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

## Output filename

If `$ARGUMENTS` is provided and looks like a path or filename, use it. Otherwise ask the user. Default to `verify.sh` (shell scripts are preferred for speed and determinism). Ensure the file ends in `.sh` or `.md`.

If writing a `.sh` file, make it executable (`chmod +x`).
