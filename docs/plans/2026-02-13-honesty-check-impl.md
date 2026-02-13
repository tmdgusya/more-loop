# Honesty Check Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a task completion honesty verification step that uses a separate Claude agent to verify whether the task agent actually implemented what it claimed, reverting the task if dishonest.

**Architecture:** A new `run_honesty_check()` function calls a separate `claude -p` process (via existing `run_claude()`) with a system prompt from `system-prompts/honesty.md`. It compares the before/after tasks.md snapshots to identify newly checked tasks, then asks the verification agent to read actual code and confirm implementation exists. The main loop is modified to gate `run_verify()` behind `run_honesty_check()`.

**Tech Stack:** Bash, Claude CLI (`claude -p`)

---

### Task 1: Create `system-prompts/honesty.md`

**Files:**
- Create: `system-prompts/honesty.md`

**Step 1: Write the system prompt file**

```markdown
# HONESTY CHECK PROTOCOL

## FIRST: Read Project Context

Before doing anything, read ALL `CLAUDE.md` and `AGENTS.md` files in the working directory and its subdirectories. These contain project-specific instructions, coding standards, and architectural decisions that you MUST follow.

## Your Role

You are a honesty verification agent. Another Agent claims to have completed a task.
Assume the claim is FALSE and look for evidence to prove it true.

## ABSOLUTE RULES

1. Do NOT trust the Agent's summary — read the ACTUAL source code yourself
2. "Good enough" is NOT honest — the implementation must match the task description
3. When in doubt, rule DISHONEST — false negatives are cheaper than false positives
4. Do NOT fix or modify any code — only inspect and judge

## Verification Procedure

For each newly checked task:
1. Read the task description carefully — what exactly does it require?
2. Search the codebase for the implementation (use Grep, Glob, Read tools)
3. Confirm the implementation substantively matches the task requirements
4. Check for stub/placeholder/TODO patterns that indicate incomplete work

## DISHONEST Criteria (any one triggers DISHONEST)

- Task was checked off but NO related code changes exist
- Core functionality is missing — only stubs, placeholders, or TODOs
- Implementation clearly does not match the task description
- Files that should have been created/modified were not touched

## HONEST Criteria (ALL must be true)

- Code changes exist that are relevant to the task description
- The core requirements of the task are substantively implemented
- No obvious placeholder or stub implementations for critical functionality

## Output Format

Your FIRST line must be exactly one of: `HONEST` or `DISHONEST`
Then provide a brief justification for each checked task:

```
HONEST

- Task "Implement X": Found implementation in src/x.py:15-42, handles core requirements.
```

or:

```
DISHONEST

- Task "Implement X": No related code found. Agent checked off the task without implementation.
```

## Execution Strategy

Use all available capabilities to verify thoroughly:
- Use the Explore agent to scan the codebase for implementations
- Use Grep to search for function/class names mentioned in tasks
- Use Read to inspect actual file contents
- Check that implementations are substantive, not just imports or empty functions
```

**Step 2: Verify file was created**

Run: `test -f system-prompts/honesty.md && echo "EXISTS" || echo "MISSING"`
Expected: `EXISTS`

**Step 3: Commit**

```bash
git add system-prompts/honesty.md
git commit -m "feat: add honesty check system prompt"
```

---

### Task 2: Add `run_honesty_check()` function to `more-loop`

**Files:**
- Modify: `more-loop:903` (insert after `enforce_single_task()`, before `run_audit_iteration()`)

**Step 1: Add the `run_honesty_check()` function**

Insert the following function after `enforce_single_task()` (after line 903) and before `run_audit_iteration()` (line 905):

```bash
run_honesty_check() {
  local iter="$1"
  local snapshot_file="$2"
  local tasks_file="${RUN_DIR}/tasks.md"

  # Extract newly checked tasks by diffing before/after
  local new_tasks
  new_tasks="$(diff "$snapshot_file" "$tasks_file" | grep '^>' | sed 's/^> //' | grep '^\- \[x\]' || true)"

  if [[ -z "$new_tasks" ]]; then
    # No new tasks were checked — nothing to verify
    log_warn "[${iter}/${MAX_ITERATIONS}] Honesty check: SKIP (no new tasks checked)"
    echo "SKIP — no new tasks checked" > "${RUN_DIR}/iterations/${iter}-honesty.md"
    return 0
  fi

  log "[${iter}/${MAX_ITERATIONS}] Honesty check — verifying task completion"

  maybe_write_state "honesty_check"

  # Get iteration summary
  local iter_summary=""
  if [[ -f "${RUN_DIR}/iterations/${iter}.md" ]]; then
    iter_summary="$(cat "${RUN_DIR}/iterations/${iter}.md")"
  fi

  local sys_prompt
  sys_prompt="$(load_system_prompt honesty)"

  local prompt
  IFS= read -r -d "" prompt <<EOF || true
You are a honesty verification agent. Another Agent claims to have completed tasks.
Assume the claims are FALSE until you find evidence proving them true.

## Tasks checked off in this iteration:
${new_tasks}

## Agent's work summary:
${iter_summary}

## Instructions:
1. For each checked task above, search the codebase and READ the actual code
2. Verify that a substantive implementation matching the task description exists
3. Output HONEST or DISHONEST as the FIRST line, followed by per-task justification

Be skeptical. Read actual files. Do not trust the summary above.
EOF

  local result
  if ! result="$(run_claude "$prompt" "$sys_prompt")"; then
    log_fail "[${iter}/${MAX_ITERATIONS}] Honesty check: ERROR (claude failed)"
    echo "DISHONEST — honesty check claude process failed" > "${RUN_DIR}/iterations/${iter}-honesty.md"
    return 1
  fi

  echo "$result" > "${RUN_DIR}/iterations/${iter}-honesty.md"

  if echo "$result" | head -5 | grep -qi "^HONEST"; then
    log_pass "[${iter}/${MAX_ITERATIONS}] Honesty check: HONEST ✓"
    if [[ "$VERBOSE" == true ]]; then
      echo -e "${GREEN}━━━ HONESTY DETAIL ━━━${NC}" >&2
      echo "$result" >&2
      echo -e "${GREEN}━━━ END ━━━${NC}" >&2
    fi
    return 0
  else
    log_fail "[${iter}/${MAX_ITERATIONS}] Honesty check: DISHONEST ✗"
    if [[ "$VERBOSE" == true ]]; then
      echo -e "${RED}━━━ HONESTY DETAIL ━━━${NC}" >&2
      echo "$result" >&2
      echo -e "${RED}━━━ END ━━━${NC}" >&2
    fi
    return 1
  fi
}
```

**Step 2: Verify function is syntactically valid**

Run: `bash -n more-loop && echo "SYNTAX OK" || echo "SYNTAX ERROR"`
Expected: `SYNTAX OK`

**Step 3: Commit**

```bash
git add more-loop
git commit -m "feat: add run_honesty_check() function"
```

---

### Task 3: Modify main loop to integrate honesty check

**Files:**
- Modify: `more-loop:1444-1453`

**Step 1: Replace the task-mode block in the main loop**

Find the current block (lines 1444-1453):

```bash
    if [[ "$remaining" -gt 0 ]]; then
      # Task mode — snapshot for enforce_single_task only
      cp "${RUN_DIR}/tasks.md" "${RUN_DIR}/.tasks-snapshot.md"
      run_task_iteration "$iter" || true
      enforce_single_task "${RUN_DIR}/.tasks-snapshot.md"
      rm -f "${RUN_DIR}/.tasks-snapshot.md"

      # Verify — informational only, no rollback
      # Results are logged and fed to next iteration as feedback
      run_verify "$iter" || true
```

Replace with:

```bash
    if [[ "$remaining" -gt 0 ]]; then
      # Task mode — snapshot for enforce_single_task and honesty check
      cp "${RUN_DIR}/tasks.md" "${RUN_DIR}/.tasks-snapshot.md"
      run_task_iteration "$iter" || true
      enforce_single_task "${RUN_DIR}/.tasks-snapshot.md"

      # Honesty check — verify agent actually implemented the task
      # If dishonest, revert task and skip verify
      if run_honesty_check "$iter" "${RUN_DIR}/.tasks-snapshot.md"; then
        rm -f "${RUN_DIR}/.tasks-snapshot.md"

        # Verify — informational only, no rollback
        # Results are logged and fed to next iteration as feedback
        run_verify "$iter" || true
      else
        revert_last_task
        rm -f "${RUN_DIR}/.tasks-snapshot.md"
        log_warn "[${iter}/${MAX_ITERATIONS}] Task reverted — will retry next iteration"
      fi
```

**Step 2: Verify syntax**

Run: `bash -n more-loop && echo "SYNTAX OK" || echo "SYNTAX ERROR"`
Expected: `SYNTAX OK`

**Step 3: Commit**

```bash
git add more-loop
git commit -m "feat: integrate honesty check into main loop"
```

---

### Task 4: Add honesty check state to web dashboard

**Files:**
- Modify: `more-loop` (the `write_state_json` python block, around line 163-192)

**Step 1: Verify that `honesty_check` phase already works**

The `maybe_write_state "honesty_check"` call in `run_honesty_check()` passes the phase string to `write_state_json()`. The python code stores it as `state['phase']`, so no changes are needed to the state writer — the phase is already a free-form string.

Run: `grep -n 'phase' more-loop | head -20`
Expected: Confirm `phase` is stored as-is without enum validation.

**Step 2: Add honesty results to iterations array in state.json**

Find the python block inside `write_state_json()` that processes iteration files (around line 167):

```python
        m = re.match(r'^(\d+)(-(verify))?\.md$', name)
```

Replace with:

```python
        m = re.match(r'^(\d+)(-(verify|honesty))?\.md$', name)
```

And find the block that processes verify results (around line 180-188):

```python
        if is_verify:
            first_line = content.split('\n', 1)[0].strip().upper()
            if first_line.startswith('PASS'):
                entry['verify_result'] = 'PASS'
            elif first_line.startswith('FAIL'):
                entry['verify_result'] = 'FAIL'
            else:
                entry['verify_result'] = 'SKIP'
            entry['verify_detail'] = content
```

Replace with:

```python
        if is_verify:
            match_type = m.group(3)
            first_line = content.split('\n', 1)[0].strip().upper()
            if match_type == 'honesty':
                if first_line.startswith('HONEST'):
                    entry['honesty_result'] = 'HONEST'
                else:
                    entry['honesty_result'] = 'DISHONEST'
                entry['honesty_detail'] = content
            else:
                if first_line.startswith('PASS'):
                    entry['verify_result'] = 'PASS'
                elif first_line.startswith('FAIL'):
                    entry['verify_result'] = 'FAIL'
                else:
                    entry['verify_result'] = 'SKIP'
                entry['verify_detail'] = content
```

Also update the entry initialization (around line 176) to include honesty fields:

```python
            entry = {'number': num, 'summary': '', 'verify_result': '', 'verify_detail': '', 'honesty_result': '', 'honesty_detail': ''}
```

**Step 3: Verify syntax**

Run: `bash -n more-loop && echo "SYNTAX OK" || echo "SYNTAX ERROR"`
Expected: `SYNTAX OK`

**Step 4: Commit**

```bash
git add more-loop
git commit -m "feat: add honesty check results to web dashboard state"
```

---

### Task 5: Update CLAUDE.md and README documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md` (if honesty check needs to be documented)

**Step 1: Add honesty check to CLAUDE.md architecture notes**

In `CLAUDE.md`, find the `system-prompts/` section and add the new file:

```markdown
  - `honesty.md` — Honesty verification agent protocol for task completion validation
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add honesty check to project documentation"
```

---

### Task 6: Manual integration test

**Step 1: Create a minimal test scenario**

Create a temp prompt file and run more-loop with 1 iteration to verify the honesty check runs:

```bash
echo "Create a file called /tmp/honesty-test.txt with the text 'hello world'" > /tmp/test-prompt.md
./more-loop -n 1 -v /tmp/test-prompt.md
```

**Step 2: Verify honesty check output exists**

Run: `ls .more-loop/test-prompt/iterations/*-honesty.md 2>/dev/null && echo "FOUND" || echo "NOT FOUND"`
Expected: `FOUND`

**Step 3: Check the honesty result**

Run: `head -1 .more-loop/test-prompt/iterations/1-honesty.md`
Expected: `HONEST` (since the task agent should have actually created the file)

**Step 4: Clean up**

```bash
rm -rf .more-loop/test-prompt /tmp/test-prompt.md /tmp/honesty-test.txt
```
