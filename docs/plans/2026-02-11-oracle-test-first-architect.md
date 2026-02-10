# Oracle Agent for Test-First Architect Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an "Oracle" agent that helps users write comprehensive Test Guides before implementation, following the Test-First Architect pattern with 5 levels of validation (Syntax, I/O, Property, Formal, Semantic).

**Architecture:**
1. Add a new `oracle` phase to more-loop that runs between bootstrap and task iterations
2. Create a new skill `more-loop-oracle` for interactive Test Guide creation
3. Create a new system prompt `oracle.md` for the Oracle agent
4. Store the Test Guide as `test-guide.md` in the run directory
5. During task iterations, include relevant Test Guide items as context

**Tech Stack:**
- Bash script modifications to `more-loop` (main executable)
- New system prompt: `system-prompts/oracle.md`
- New skill: `.claude/skills/more-loop-oracle/SKILL.md`
- Modifications to `install.sh` for deployment

---

## Task 1: Create the Oracle system prompt

**Files:**
- Create: `system-prompts/oracle.md`

**Step 1: Write the Oracle system prompt**

```markdown
# ORACLE PROTOCOL

## FIRST: Read Project Context

Before doing anything, read ALL `CLAUDE.md` and `AGENTS.md` files in the working directory and its subdirectories. These contain project-specific instructions, coding standards, and architectural decisions that you MUST follow.

## Purpose

You are the Oracle — a Test-First Architect agent. Your job is to help the user write a comprehensive Test Guide that defines "correctness" BEFORE implementation begins.

## The 5 Oracle Levels

You must guide the user through these 5 levels of testing. For each level, ask specific questions to build a complete Test Guide:

### Lv.1: Syntax (Does it run?)
- Build/compile success
- Type checking passes
- No syntax errors
- Linting rules pass
- Examples: "TypeScript compiles without errors", "Rust builds without warnings"

### Lv.2: I/O (Does it work for given inputs?)
- Unit tests for core functions
- Integration tests for API endpoints
- Example inputs with expected outputs
- Edge cases for inputs
- Examples: "POST /users returns 201 with user object", "divide(10, 2) returns 5"

### Lv.3: Property (What invariants hold?)
- Property-based tests (Hypothesis, fast-check)
- "For all valid inputs, X must be true"
- Randomized testing with constraints
- Examples: "For any non-negative integers a, b: gcd(a, b) divides both a and b"

### Lv.4: Formal (What are the business rules?)
- Business invariants as code contracts
- State transition rules
- Resource allocation constraints
- Examples: "Account balance is never negative", "A user cannot be both admin and guest"

### Lv.5: Semantic (Does it meet user intent?)
- UI/UX acceptance criteria (Gherkin scenarios)
- Accessibility requirements
- Performance benchmarks
- Security requirements
- Examples: "Given a logged-in user, when they click logout, then they are redirected to login page"

## Questioning Strategy

1. **Start with the spec** — Read `prompt.md` to understand what's being built
2. **Ask level-by-level** — For each Oracle level, ask specific questions
3. **Build the Test Guide** — Document answers as testable criteria
4. **Don't move on** — Stay at a level until the user provides sufficient answers
5. **Be specific** — Reject vague answers like "it should work well"

## Output Format

Write the Test Guide to `{run_dir}/test-guide.md` in this format:

```markdown
# Test Guide: {project-name}

## Level 1: Syntax (Does it run?)
- [ ] <specific, testable criterion>
- [ ] <another criterion>

## Level 2: I/O (Does it work?)
### Core Functions
- [ ] <function_name> with <input> returns <output>
- [ ] <function_name> handles <edge case>

### API Endpoints
- [ ] <METHOD> <path> returns <status> with <response shape>

## Level 3: Property (What invariants hold?)
- [ ] For all <valid inputs>, <property must hold>
- [ ] <invariant> is always true

## Level 4: Formal (What are the business rules?)
- [ ] <business rule as contract>
- [ ] <state constraint>

## Level 5: Semantic (Does it meet user intent?)
### Gherkin Scenarios
- [ ] Scenario: <title>
  Given <precondition>
  When <action>
  Then <outcome>

### Non-Functional Requirements
- [ ] Performance: <metric>
- [ ] Security: <requirement>
- [ ] Accessibility: <criterion>
```

## ABSOLUTE RULES

1. Do NOT accept vague criteria — every item must be testable
2. Do NOT skip levels — all 5 levels must be addressed
3. Do NOT write implementation code — only define tests
4. Do NOT move to the next phase until the user approves the Test Guide

## Completion Criteria

The Oracle phase is complete when:
1. All 5 Oracle levels have at least one testable criterion
2. Each criterion is specific and verifiable
3. The user has reviewed and approved the Test Guide
4. `test-guide.md` is written to the run directory
```

**Step 2: Verify the file was created**

Run: `ls -la system-prompts/oracle.md`
Expected: File exists with content above

**Step 3: Commit**

```bash
git add system-prompts/oracle.md
git commit -m "feat: add Oracle system prompt for Test-First Architect phase"
```

---

## Task 2: Create the Oracle skill for interactive Test Guide creation

**Files:**
- Create: `.claude/skills/more-loop-oracle/SKILL.md`

**Step 1: Write the Oracle skill**

```markdown
---
name: more-loop-oracle
description: Create a comprehensive Test Guide using the Oracle Test-First Architect methodology before implementation
disable-model-invocation: true
argument-hint: "[run-name]"
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion, Bash
---

# Create a Test Guide with the Oracle

You are the **Oracle** — a Test-First Architect that helps users write comprehensive Test Guides BEFORE implementation begins.

## The Oracle Philosophy

"Before asking AI to build something, first define what 'correct' means."

A Test Guide is the "answer key" that defines correctness. Without it, you cannot verify if the implementation is right.

## The 5 Oracle Levels

Guide the user through these 5 levels systematically:

### Level 1: Syntax (Does it run?)
Questions to ask:
- "What build/compile command must pass?"
- "Are there type checking requirements?"
- "What linting rules should be enforced?"
- "Are there specific compiler warnings that must not appear?"

Example criteria:
- [ ] `npm run build` completes without errors
- [ ] `tsc --noEmit` passes with no type errors
- [ ] `ruff check` passes with zero warnings

### Level 2: I/O (Does it work?)
Questions to ask:
- "What are the core functions and their expected inputs/outputs?"
- "What API endpoints exist and what should they return?"
- "What are the edge cases for each function/endpoint?"
- "What error cases should be handled?"

Example criteria:
- [ ] `add(a, b)` returns the sum of two numbers
- [ ] `add(-5, 3)` returns `-2` (handles negative numbers)
- [ ] `POST /api/users` returns 201 with `{ id, name, email }`
- [ ] `POST /api/users` with invalid email returns 400

### Level 3: Property (What invariants hold?)
Questions to ask:
- "What properties are true for ALL valid inputs?"
- "Are there mathematical relationships that must hold?"
- "What should NEVER happen regardless of input?"

Example criteria:
- [ ] For all integers a, b: `add(a, b) == add(b, a)` (commutativity)
- [ ] For all strings s: `reverse(reverse(s)) == s`
- [ ] No matter the input, `parse_user()` never returns null

### Level 4: Formal (What are the business rules?)
Questions to ask:
- "What are the critical business invariants?"
- "What state transitions are allowed/disallowed?"
- "What constraints must the system always maintain?"

Example criteria:
- [ ] Account balance is never negative (must reject overdrafts)
- [ ] An order cannot be both 'pending' and 'shipped' simultaneously
- [ ] User email addresses are unique across the system

### Level 5: Semantic (Does it meet user intent?)
Questions to ask:
- "What are the key user scenarios? (Gherkin format)"
- "What are the performance requirements?"
- "What are the security requirements?"
- "What accessibility standards must be met?"

Example criteria:
- [ ] Scenario: Successful login
  Given a registered user with valid credentials
  When they submit username and password
  Then they are redirected to the dashboard
  And a session token is stored

- [ ] API response time is < 200ms for 95th percentile
- [ ] All user inputs are sanitized against XSS
- [ ] All interactive elements are keyboard accessible

## Your Process

1. **Read the spec** — Find the `prompt.md` file to understand what's being built
2. **Determine run name** — Use `$ARGUMENTS` if provided, or derive from spec
3. **Go level by level** — Start at Level 1, don't skip ahead
4. **Ask specific questions** — Use `AskUserQuestion` with options when possible
5. **Reject vague answers** — If the user says "test everything", ask "what specifically?"
6. **Document everything** — Build the Test Guide iteratively
7. **Get approval** — Before finishing, show the complete Test Guide and ask for approval

## Output Format

Write to `.more-loop/runs/<run-name>/test-guide.md`:

```markdown
# Test Guide: <project-name>

## Level 1: Syntax (Does it run?)
- [ ] <specific criterion>
- [ ] <specific criterion>

## Level 2: I/O (Does it work?)
### Core Functions
- [ ] <function>: <input> → <output>
- [ ] <function>: <edge case> → <expected result>

### API Endpoints
- [ ] <METHOD> <path> → <status> with <response shape>

## Level 3: Property (What invariants hold?)
- [ ] For all <domain>: <property must hold>
- [ ] <invariant> is always true

## Level 4: Formal (What are the business rules?)
- [ ] <business rule as contract>
- [ ] <state constraint>

## Level 5: Semantic (Does it meet user intent?)
### Gherkin Scenarios
- [ ] Scenario: <title>
  Given <precondition>
  When <action>
  Then <outcome>

### Non-Functional Requirements
- [ ] Performance: <metric>
- [ ] Security: <requirement>
- [ ] Accessibility: <criterion>
```

## Quality Checklist

Before declaring the Test Guide complete, verify:
- [ ] All 5 levels have at least 3 criteria
- [ ] Each criterion is specific and testable
- [ ] No vague criteria like "works correctly" or "is efficient"
- [ ] Edge cases are covered (null, empty, negative, boundary values)
- [ ] Business rules are explicit
- [ ] User scenarios are in Gherkin format

## Common Pitfalls

**Vague criteria to reject:**
- "Code is clean" → Ask: "What specific code quality rules?"
- "It's fast" → Ask: "What's the exact performance requirement?"
- "It handles errors" → Ask: "Which errors, and how should they be handled?"
- "Tests exist" → Ask: "What specific test cases must exist?"

**Better alternatives:**
- "Functions have type annotations" (Syntax)
- "API responds within 200ms for 95% of requests" (Semantic)
- "Division by zero returns a Result::Err variant" (I/O)
- "All public functions have doc strings with examples" (Syntax)
```

**Step 2: Verify the skill file was created**

Run: `cat .claude/skills/more-loop-oracle/SKILL.md | head -20`
Expected: First 20 lines of the skill file

**Step 3: Commit**

```bash
git add .claude/skills/more-loop-oracle/SKILL.md
git commit -m "feat: add Oracle skill for Test Guide creation"
```

---

## Task 3: Add --oracle flag to more-loop

**Files:**
- Modify: `more-loop` (lines 14-26: add ORACLE_MODE variable)
- Modify: `more-loop` (lines 54-78: add --oracle to usage and parse_args)
- Modify: `more-loop` (lines 234-334: update parse_args to handle --oracle)

**Step 1: Add ORACLE_MODE variable**

After line 19 (APPROVE_TIMEOUT), add:

```bash
ORACLE_MODE=false
```

**Step 2: Add --oracle to usage()**

Add this line to the options table (after line 77):

```bash
  --oracle                Enable Oracle Test-First Architect phase before iterations
```

**Step 3: Add --oracle flag to parse_args()**

After the `--port` case (around line 280), add:

```bash
      --oracle)
        ORACLE_MODE=true
        shift
        ;;
```

**Step 4: Verify the changes**

Run: `grep -n "ORACLE" more-loop`
Expected: 3 matches (variable, usage, parse_args case)

**Step 5: Test the help output**

Run: `./more-loop --help | grep -A1 oracle`
Expected: Shows the --oracle option description

**Step 6: Commit**

```bash
git add more-loop
git commit -m "feat: add --oracle flag to more-loop"
```

---

## Task 4: Add run_oracle_phase() function to more-loop

**Files:**
- Modify: `more-loop` (after line 590: after rebootstrap function)

**Step 1: Write the run_oracle_phase() function**

After the `rebootstrap()` function (around line 590), add:

```bash
run_oracle_phase() {
  log "[Oracle] Test-First Architect phase — building Test Guide"

  maybe_write_state "oracle"

  local spec
  spec="$(cat "$PROMPT_FILE")"

  local sys_prompt
  sys_prompt="$(load_system_prompt oracle)"

  local prompt
  IFS= read -r -d "" prompt <<EOF || true
You are the Oracle — a Test-First Architect agent.

Your job is to help the user write a comprehensive Test Guide that defines
"correctness" BEFORE implementation begins.

## Spec:
${spec}

## Instructions:
1. Read the spec carefully
2. Guide the user through the 5 Oracle levels (Syntax, I/O, Property, Formal, Semantic)
3. Ask specific questions to build testable criteria
4. Document everything in ${RUN_DIR}/test-guide.md
5. Get user approval before completing

Use the AskUserQuestion tool to interact with the user.
Do NOT proceed to the next level until the current level has sufficient criteria.
Do NOT accept vague answers — every criterion must be specific and testable.

The Test Guide will be used during task iterations to provide context about
what "correct" means for each implementation task.
EOF

  local output
  if ! output="$(run_claude "$prompt" "$sys_prompt")"; then
    log_fail "Oracle phase failed"
    echo "$output" > "${RUN_DIR}/iterations/oracle.md"
    return 1
  fi

  echo "$output" > "${RUN_DIR}/iterations/oracle.md"

  # Verify test-guide.md was created
  if [[ ! -f "${RUN_DIR}/test-guide.md" ]]; then
    log_warn "Oracle phase completed but test-guide.md not found"
    return 1
  fi

  log_pass "[Oracle] Test Guide created at ${RUN_DIR}/test-guide.md"
  maybe_write_state "bootstrap"
}
```

**Step 2: Verify the function exists**

Run: `grep -n "run_oracle_phase" more-loop`
Expected: Shows the function definition

**Step 3: Commit**

```bash
git add more-loop
git commit -m "feat: add run_oracle_phase() function"
```

---

## Task 5: Integrate Oracle phase into main loop

**Files:**
- Modify: `more-loop` (lines 1290-1336: main() function after bootstrap)

**Step 1: Call run_oracle_phase after bootstrap**

Find the approval checkpoint after bootstrap (around line 1328-1335).
After the `if ! bootstrap; then ... fi` block, add:

```bash
  # Oracle phase (if enabled)
  if [[ "$ORACLE_MODE" == "true" ]]; then
    if ! run_oracle_phase; then
      log_warn "Oracle phase failed, continuing without Test Guide"
    fi
    echo ""

    # Approval checkpoint after Oracle
    if [[ "$APPROVE_MODE" == "true" ]]; then
      if ! wait_for_approval "oracle"; then
        log "Run stopped by user"
        maybe_write_state "done"
        exit 0
      fi
    fi
  fi
```

**Step 2: Verify the integration**

Run: `grep -n "ORACLE_MODE" more-loop | grep "true"`
Expected: Should show the new conditional block

**Step 3: Test basic flow**

Run: `./more-loop --help | grep oracle`
Expected: Shows --oracle in help

**Step 4: Commit**

```bash
git add more-loop
git commit -m "feat: integrate Oracle phase into main loop"
```

---

## Task 6: Include Test Guide in task iteration prompts

**Files:**
- Modify: `more-loop` (lines 604-670: run_task_iteration function)

**Step 1: Add test_guide_content to prompt**

Find the `run_task_iteration()` function and locate where it builds the prompt
(around line 640-660). After the `verify_info` variable, add:

```bash
  # Include Test Guide if available (Oracle phase output)
  local test_guide_info=""
  if [[ -f "${RUN_DIR}/test-guide.md" ]]; then
    test_guide_info="## Test Guide (Oracle output — defines correctness criteria):
$(cat "${RUN_DIR}/test-guide.md")"
  fi
```

**Step 2: Add test_guide_info to the prompt**

Find the prompt construction in `run_task_iteration()`. After the `${verify_info}` line,
add the test guide section:

```bash
You are on iteration ${iter} of ${MAX_ITERATIONS} in an iterative development process.

## Current tasks (${remaining} remaining):
${tasks}

## Acceptance criteria:
${acceptance}

${test_guide_info}

${prev_summary}

${verify_info}

## Instructions:
1. Pick the NEXT unchecked task ("- [ ]") from tasks.md
2. Implement it fully
3. Mark it as done by changing "- [ ]" to "- [x]" in ${RUN_DIR}/tasks.md
4. Write a brief summary of what you did to stdout

Do ONE task only. Be thorough but focused.
```

**Step 3: Verify the changes**

Run: `grep -n "test_guide" more-loop`
Expected: Shows test_guide_info variable and its usage

**Step 4: Commit**

```bash
git add more-loop
git commit -m "feat: include Test Guide in task iteration prompts"
```

---

## Task 7: Update install.sh to deploy Oracle files

**Files:**
- Modify: `install.sh`
- Modify: `Makefile`

**Step 1: Add Oracle skill to install.sh**

Find the skills installation section (lines 33-39). Add the Oracle skill:

```bash
  # Skills — remove first to handle existing symlinks
  mkdir -p "$SKILLS_DIR/more-loop-prompt"
  mkdir -p "$SKILLS_DIR/more-loop-verify"
  mkdir -p "$SKILLS_DIR/more-loop-oracle"
  rm -f "$SKILLS_DIR/more-loop-prompt/SKILL.md" \
     "$SKILLS_DIR/more-loop-verify/SKILL.md" \
     "$SKILLS_DIR/more-loop-oracle/SKILL.md"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-prompt/SKILL.md" "$SKILLS_DIR/more-loop-prompt/SKILL.md"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-verify/SKILL.md" "$SKILLS_DIR/more-loop-verify/SKILL.md"
  cp "$SCRIPT_DIR/.claude/skills/more-loop-oracle/SKILL.md" "$SKILLS_DIR/more-loop-oracle/SKILL.md"
  echo "  Installed skills to $SKILLS_DIR/"
```

**Step 2: Add Oracle skill to uninstall**

Find the uninstall section (lines 75-89). Add the Oracle skill:

```bash
  rm -rf "$SKILLS_DIR/more-loop-prompt"
  rm -rf "$SKILLS_DIR/more-loop-verify"
  rm -rf "$SKILLS_DIR/more-loop-oracle"
```

**Step 3: Update Makefile**

Add the Oracle skill to the install targets. Find the skills copy section:

```makefile
	# Skills
	mkdir -p $(DESTDIR)$(SKILLS_DIR)/more-loop-prompt
	mkdir -p $(DESTDIR)$(SKILLS_DIR)/more-loop-verify
	mkdir -p $(DESTDIR)$(SKILLS_DIR)/more-loop-oracle
	rm -f $(DESTDIR)$(SKILLS_DIR)/more-loop-prompt/SKILL.md \
	   $(DESTDIR)$(SKILLS_DIR)/more-loop-verify/SKILL.md \
	   $(DESTDIR)$(SKILLS_DIR)/more-loop-oracle/SKILL.md
	$(INSTALL_DATA) $(CURDIR)/.claude/skills/more-loop-prompt/SKILL.md \
		$(DESTDIR)$(SKILLS_DIR)/more-loop-prompt/
	$(INSTALL_DATA) $(CURDIR)/.claude/skills/more-loop-verify/SKILL.md \
		$(DESTDIR)$(SKILLS_DIR)/more-loop-verify/
	$(INSTALL_DATA) $(CURDIR)/.claude/skills/more-loop-oracle/SKILL.md \
		$(DESTDIR)$(SKILLS_DIR)/more-loop-oracle/
```

**Step 4: Verify the changes**

Run: `grep -n "oracle" install.sh Makefile`
Expected: Shows oracle in both files (case-insensitive)

**Step 5: Commit**

```bash
git add install.sh Makefile
git commit -m "feat: add Oracle skill to install scripts"
```

---

## Task 8: Create test-guide.md example documentation

**Files:**
- Create: `docs/test-guide-example.md`

**Step 1: Write the test guide example**

```markdown
# Test Guide Example

This is an example of a complete Test Guide created by the Oracle phase.

## Example: Simple Calculator API

### Level 1: Syntax (Does it run?)

- [ ] `npm run build` completes without errors
- [ ] `tsc --noEmit` passes with zero type errors
- [ ] `eslint src/` passes with zero warnings
- [ ] All TypeScript files have corresponding `.test.ts` files

### Level 2: I/O (Does it work?)

#### Core Functions

- [ ] `add(a, b)` returns the sum of two numbers
- [ ] `add(0, x)` returns `x` (identity)
- [ ] `add(-5, 3)` returns `-2` (handles negative numbers)
- [ ] `add(Number.MAX_SAFE_INTEGER, 1)` returns `Number.MAX_SAFE_INTEGER + 1` (handles large numbers)
- [ ] `divide(10, 2)` returns `5`
- [ ] `divide(10, 0)` throws `DivisionByZeroError`

#### API Endpoints

- [ ] `GET /api/health` returns `200` with `{ status: "ok" }`
- [ ] `POST /api/calculate` with `{ operation: "add", a: 5, b: 3 }` returns `200` with `{ result: 8 }`
- [ ] `POST /api/calculate` with invalid operation returns `400` with `{ error: "Invalid operation" }`
- [ ] `POST /api/calculate` with missing fields returns `400` with error details

### Level 3: Property (What invariants hold?)

- [ ] For all numbers a, b, c: `add(add(a, b), c) === add(a, add(b, c))` (associativity)
- [ ] For all numbers a, b: `add(a, b) === add(b, a)` (commutativity)
- [ ] For all numbers x: `add(x, 0) === x` (identity element)
- [ ] For all non-zero numbers a: `multiply(a, 1) === a` (identity for multiplication)
- [ ] For all numbers a, b: `divide(a, b) * b === a` (within floating-point precision)

### Level 4: Formal (What are the business rules?)

- [ ] Results are always finite numbers (never `NaN` or `Infinity` unless explicitly requested)
- [ ] Integer operations never lose precision (use BigInt when necessary)
- [ ] Division by zero always throws a specific error, never returns `NaN`
- [ ] All API responses include a `requestId` for tracing
- [ ] Rate limiting: max 100 requests per minute per IP

### Level 5: Semantic (Does it meet user intent?)

#### Gherkin Scenarios

- [ ] Scenario: Basic addition
  Given the calculator API is running
  When I send a POST request to `/api/calculate` with `{ "operation": "add", "a": 5, "b": 3 }`
  Then the response status is 200
  And the response body contains `{ "result": 8 }`

- [ ] Scenario: Division by zero
  Given the calculator API is running
  When I send a POST request to `/api/calculate` with `{ "operation": "divide", "a": 10, "b": 0 }`
  Then the response status is 400
  And the response body contains `{ "error": "Division by zero" }`

- [ ] Scenario: Invalid operation
  Given the calculator API is running
  When I send a POST request to `/api/calculate` with `{ "operation": "modulo", "a": 10, "b": 3 }`
  Then the response status is 400
  And the response body contains `{ "error": "Invalid operation: modulo" }`

#### Non-Functional Requirements

- [ ] Performance: 95th percentile response time < 50ms
- [ ] Security: All inputs are validated against numeric injection
- [ ] Security: API rate limiting is enforced per IP address
- [ ] Accessibility: API documentation includes examples for all operations
- [ ] Observability: All requests are logged with operation, inputs, and result

## How This Test Guide Is Used

During task iterations, the Test Guide provides context about what "correct" means:

1. When implementing the `add` function, Claude sees the I/O criteria and property tests
2. When implementing the `/api/calculate` endpoint, Claude sees the expected API contract
3. When writing tests, Claude sees that property-based tests are required
4. When reviewing code, Claude verifies that business rules (like no NaN results) are enforced
```

**Step 2: Verify the file was created**

Run: `wc -l docs/test-guide-example.md`
Expected: File has 60+ lines

**Step 3: Commit**

```bash
git add docs/test-guide-example.md
git commit -m "docs: add Test Guide example documentation"
```

---

## Task 9: Update README.md with Oracle documentation

**Files:**
- Modify: `README.md`

**Step 1: Add Oracle to usage section**

Find the options table (around line 69-81). Add a new row after `--approve-every`:

```markdown
| `--oracle` | off | Enable Oracle Test-First Architect phase before iterations |
```

**Step 2: Add Oracle section to README**

Find the "Bundled skills" section (around line 124-131). Add a new section after it:

```markdown
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
```

**Step 3: Update skills section**

Modify the bundled skills section to include Oracle:

```markdown
## Bundled skills

This repo includes three Claude Code skills:

- **`/more-loop-prompt`** — Interactive wizard to create a `prompt.md` spec file
- **`/more-loop-verify`** — Interactive wizard to create a `verify.sh` or `verify.md` verification file
- **`/more-loop-oracle`** — Interactive Test-First Architect to create comprehensive Test Guides
```

**Step 4: Verify the changes**

Run: `grep -n "oracle\|Oracle" README.md`
Expected: Multiple matches showing documentation added

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add Oracle documentation to README"
```

---

## Task 10: Update CLAUDE.md with Oracle architecture notes

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add Oracle architecture notes**

Add to the "more-loop Architecture Notes" section:

```markdown
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
```

**Step 2: Verify the changes**

Run: `grep -n "oracle\|Oracle" CLAUDE.md`
Expected: Shows Oracle notes added

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add Oracle architecture notes to CLAUDE.md"
```

---

## Task 11: Create Oracle verification tests

**Files:**
- Create: `.more-loop/runs/oracle-test/verify.sh`

**Step 1: Write the Oracle verification script**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Oracle Feature Verification ==="

RUN_DIR=".more-loop/runs/oracle-test"

# Test 1: --oracle flag exists in help
echo "Checking --oracle flag in help..."
if ./more-loop --help | grep -q -- "--oracle"; then
  echo "PASS: --oracle flag documented in help"
else
  echo "FAIL: --oracle flag not found in help"
  exit 1
fi

# Test 2: Oracle system prompt exists
echo "Checking Oracle system prompt..."
if [[ -f "system-prompts/oracle.md" ]]; then
  echo "PASS: system-prompts/oracle.md exists"
else
  echo "FAIL: system-prompts/oracle.md not found"
  exit 1
fi

# Test 3: Oracle skill exists
echo "Checking Oracle skill..."
if [[ -f ".claude/skills/more-loop-oracle/SKILL.md" ]]; then
  echo "PASS: .claude/skills/more-loop-oracle/SKILL.md exists"
else
  echo "FAIL: Oracle skill not found"
  exit 1
fi

# Test 4: Oracle skill has required sections
echo "Checking Oracle skill content..."
if grep -q "5 Oracle Levels" .claude/skills/more-loop-oracle/SKILL.md; then
  echo "PASS: Oracle skill contains 5 Oracle Levels section"
else
  echo "FAIL: Oracle skill missing 5 Oracle Levels section"
  exit 1
fi

# Test 5: run_oracle_phase function exists in more-loop
echo "Checking run_oracle_phase function..."
if grep -q "^run_oracle_phase()" more-loop; then
  echo "PASS: run_oracle_phase function exists"
else
  echo "FAIL: run_oracle_phase function not found"
  exit 1
fi

# Test 6: Test Guide example documentation exists
echo "Checking Test Guide example..."
if [[ -f "docs/test-guide-example.md" ]]; then
  echo "PASS: docs/test-guide-example.md exists"
else
  echo "FAIL: Test Guide example not found"
  exit 1
fi

echo ""
echo "=== All Oracle feature tests passed ==="
```

**Step 2: Make the script executable**

Run: `chmod +x .more-loop/runs/oracle-test/verify.sh`

**Step 3: Run the verification tests**

Run: `bash .more-loop/runs/oracle-test/verify.sh`
Expected: All tests pass

**Step 4: Commit**

```bash
git add .more-loop/runs/oracle-test/verify.sh
git commit -m "test: add Oracle feature verification tests"
```

---

## Task 12: Create end-to-end integration test for Oracle flow

**Files:**
- Create: `tests/test-oracle-integration.sh`

**Step 1: Create tests directory**

Run: `mkdir -p tests`

**Step 2: Write the integration test**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Integration test for Oracle phase in more-loop
# This test verifies that the Oracle phase creates a test-guide.md file

echo "=== Oracle Integration Test ==="

# Setup
TEST_DIR="$(mktemp -d)"
cd "$TEST_DIR"

# Copy more-loop to test directory
cp -r /home/roach/more-loop/.claude .claude
cp /home/roach/more-loop/more-loop more-loop
chmod +x more-loop
mkdir -p system-prompts
cp /home/roach/more-loop/system-prompts/*.md system-prompts/

# Create a simple prompt file
cat > prompt.md <<'EOF'
# Test Project

Build a simple function that adds two numbers.
EOF

# Run more-loop with --oracle for 1 iteration
# (The Oracle phase should run before any task iterations)
echo "Running more-loop with --oracle flag..."
timeout 60 ./more-loop --oracle -n 1 prompt.md 2>&1 | tee output.log || true

# Check if test-guide.md was created in the run directory
RUN_DIR="$(find .more-loop -name "prompt-*" -type d | head -1)"
if [[ -z "$RUN_DIR" ]]; then
  echo "FAIL: No run directory created"
  exit 1
fi

echo "Run directory: $RUN_DIR"

if [[ -f "$RUN_DIR/test-guide.md" ]]; then
  echo "PASS: test-guide.md was created"
  echo "Content preview:"
  head -20 "$RUN_DIR/test-guide.md"
else
  echo "INFO: test-guide.md not created (may require interactive Oracle session)"
fi

# Check that iterations/oracle.md was created
if [[ -f "$RUN_DIR/iterations/oracle.md" ]]; then
  echo "PASS: iterations/oracle.md was created"
else
  echo "INFO: iterations/oracle.md not found (Oracle may not have completed)"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

echo ""
echo "=== Oracle integration test complete ==="
```

**Step 3: Make the test executable**

Run: `chmod +x tests/test-oracle-integration.sh`

**Step 4: Run the integration test**

Run: `bash tests/test-oracle-integration.sh`
Expected: Test completes successfully

**Step 5: Commit**

```bash
git add tests/test-oracle-integration.sh
git commit -m "test: add Oracle integration test"
```

---

## Task 13: Create Korean README update

**Files:**
- Modify: `README_ko.md`

**Step 1: Read Korean README to understand structure**

Run: `head -50 README_ko.md`
Expected: See Korean documentation structure

**Step 2: Add Oracle documentation to Korean README**

Find the options section and add:

```markdown
| `--oracle` | off | Oracle Test-First Architect 단계 활성화 (반복 전) |
```

Add a new section after "Bundled skills":

```markdown
## Oracle: Test-First Architect 단계

`--oracle` 플래그는 코드를 작성하기 전에 포괄적인 테스트 기준을 정의하는 사전 구현 단계를 활성화합니다. 이는 Test-First Architect 패턴을 따릅니다:

### Oracle이 하는 일

1. **5가지 Oracle 레벨 안내** — Syntax, I/O, Property, Formal, Semantic
2. **구체적인 질문** — 테스트 가능한 기준으로 테스트 가이드 작성
3. **`test-guide.md` 생성** — 작업 반복 중 컨텍스트로 사용됨
4. **완성도 보장** — 모든 레벨에 충분한 기준이 있을 때까지 완료하지 않음

### 5가지 Oracle 레벨

| 레벨 | 질문 | 예시 |
|------|------|------|
| Lv.1: Syntax | 실행되는가? | "빌드 성공, 타입 검사 통과" |
| Lv.2: I/O | 작동하는가? | "add(5, 3)은 8 반환, POST /users는 201 반환" |
| Lv.3: Property | 어떤 불변식이 있는가? | "모든 a, b에 대해: add(a, b) == add(b, a)" |
| Lv.4: Formal | 비즈니스 규칙은? | "계좌 잔액은 음수가 될 수 없음" |
| Lv.5: Semantic | 사용자 의도를 충족하는가? | "로그인한 사용자가 로그아웃하면 로그인 페이지 표시" |

### 사용 예

```bash
# Oracle 단계와 함께
more-loop --oracle prompt.md verify.sh

# Oracle + 승인 모드
more-loop --oracle --approve prompt.md verify.sh
```

전체 Test Guide 예시는 `docs/test-guide-example.md`를 참조하세요.
```

**Step 3: Verify the changes**

Run: `grep -n "oracle\|Oracle" README_ko.md`
Expected: Shows Korean Oracle documentation

**Step 4: Commit**

```bash
git add README_ko.md
git commit -m "docs: add Oracle documentation to Korean README"
```

---

## Task 14: Update project structure documentation in README

**Files:**
- Modify: `README.md` (Project structure section)

**Step 1: Add Oracle to project structure tree**

Find the project structure section (around line 169-185). Update it:

```markdown
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
```

**Step 2: Verify the structure tree is valid markdown**

Run: `grep -A25 "## Project structure" README.md | head -30`
Expected: Shows the updated structure tree

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update project structure with Oracle files"
```

---

## Task 15: Final integration test and documentation

**Files:**
- Modify: None (verification task)

**Step 1: Run all verification tests**

Run: `bash .more-loop/runs/oracle-test/verify.sh`
Expected: All tests pass

**Step 2: Run integration test**

Run: `bash tests/test-oracle-integration.sh`
Expected: Integration test completes

**Step 3: Verify help output**

Run: `./more-loop --help | grep -A1 oracle`
Expected: Shows --oracle option

**Step 4: Check all files are in git**

Run: `git status`
Expected: All new files are tracked

**Step 5: Create summary commit**

```bash
git add -A
git commit -m "feat: complete Oracle Test-First Architect implementation

This adds the Oracle phase to more-loop, which helps users create
comprehensive Test Guides before implementation begins.

Features:
- New --oracle flag to enable Oracle phase
- 5-level Oracle methodology: Syntax, I/O, Property, Formal, Semantic
- New skill: /more-loop-oracle for interactive Test Guide creation
- New system prompt: system-prompts/oracle.md
- Test Guide (test-guide.md) used as context during task iterations
- Complete documentation and examples

See docs/test-guide-example.md for a complete Test Guide example."
```

---

## Summary

This plan implements the Oracle Test-First Architect agent for more-loop. Upon completion:

1. **New phase** — Oracle runs between bootstrap and task iterations
2. **New skill** — `/more-loop-oracle` for interactive Test Guide creation
3. **New system prompt** — `system-prompts/oracle.md` defines Oracle behavior
4. **5-level methodology** — Syntax, I/O, Property, Formal, Semantic
5. **Integration** — Test Guide provides context during task iterations
6. **Documentation** — Complete examples and bilingual documentation

The Oracle ensures users define "correctness" BEFORE implementation, following the Test-First Architect pattern from the article.
