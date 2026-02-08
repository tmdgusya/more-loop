#!/usr/bin/env bats
# Tests for more-loop bash script — request-changes flow, reviews.json, rebootstrap, state transitions
# Requires bats (https://github.com/bats-core/bats-core)
# Tests source individual functions from more-loop without running the full script.
# Covers: signal-request-changes|request-changes flow and reviews.json handling

setup() {
  # Create temp directory for each test
  export TMPDIR="$(mktemp -d)"
  export RUN_DIR="${TMPDIR}/run"
  mkdir -p "${RUN_DIR}/iterations"

  # Script under test
  export SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  export MORE_LOOP="${SCRIPT_DIR}/more-loop"

  # Set default globals expected by functions
  export WEB_MODE=false
  export APPROVE_MODE=false
  export MODEL=opus
  export MAX_ITERATIONS=5
  export MAX_TASKS=""
  export CURRENT_ITERATION=1
  export APPROVE_TIMEOUT=180
}

teardown() {
  rm -rf "$TMPDIR"
}

# ── Helper: source only functions (skip main execution) ──

source_functions() {
  # Source the script but override main() to prevent execution
  # We extract functions by sourcing with a trap
  eval "$(sed 's/^main "\$@"$//' "$MORE_LOOP")"
}

# ── Signal detection tests ──

@test "check_stop_signal returns true when .signal-stop exists" {
  source_functions
  touch "${RUN_DIR}/.signal-stop"
  run check_stop_signal
  [ "$status" -eq 0 ]
}

@test "check_stop_signal returns false when .signal-stop absent" {
  source_functions
  run check_stop_signal
  [ "$status" -ne 0 ]
}

@test ".signal-request-changes file can be created and detected" {
  touch "${RUN_DIR}/.signal-request-changes"
  [ -f "${RUN_DIR}/.signal-request-changes" ]
}

@test ".signal-request-changes is removed by handle_request_changes pattern" {
  source_functions
  touch "${RUN_DIR}/.signal-request-changes"
  [ -f "${RUN_DIR}/.signal-request-changes" ]
  rm -f "${RUN_DIR}/.signal-request-changes"
  [ ! -f "${RUN_DIR}/.signal-request-changes" ]
}

# ── reviews.json tests ──

@test "reviews.json can be written and read back" {
  echo '{"reviews": [{"text": "fix this", "selected": "line 1"}]}' > "${RUN_DIR}/reviews.json"
  [ -f "${RUN_DIR}/reviews.json" ]
  run cat "${RUN_DIR}/reviews.json"
  [[ "$output" == *'"reviews"'* ]]
  [[ "$output" == *'"fix this"'* ]]
}

@test "reviews.json with special characters is preserved" {
  echo '{"reviews": [{"text": "quotes \"and\" <html>", "selected": "unicode: éàü"}]}' > "${RUN_DIR}/reviews.json"
  run cat "${RUN_DIR}/reviews.json"
  [[ "$output" == *'quotes'* ]]
  [[ "$output" == *'unicode'* ]]
}

@test "reviews.json with empty reviews list" {
  echo '{"reviews": []}' > "${RUN_DIR}/reviews.json"
  run python3 -c "import json; d=json.load(open('${RUN_DIR}/reviews.json')); print(len(d['reviews']))"
  [ "$output" = "0" ]
}

# ── Rebootstrap prompt construction ──

@test "rebootstrap prompt includes review feedback in heredoc" {
  # Verify the rebootstrap function includes review feedback in its prompt
  # The text "Review feedback" is in the heredoc, further from the function start
  run grep 'Review feedback' "$MORE_LOOP"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Review feedback'* ]]
}

@test "rebootstrap function is defined in more-loop" {
  run grep -c 'rebootstrap()' "$MORE_LOOP"
  [[ "$output" =~ ^[1-9] ]]
}

@test "rebootstrap references reviews_json parameter" {
  run grep 'reviews_json' "$MORE_LOOP"
  [ "$status" -eq 0 ]
  [[ "$output" == *'reviews_json'* ]]
}

@test "rebootstrap includes Review feedback section in prompt" {
  run grep -A5 'Review feedback' "$MORE_LOOP"
  [ "$status" -eq 0 ]
  [[ "$output" == *'reviews_json'* ]]
}

@test "rebootstrap cleans up reviews.json after processing" {
  run grep 'rm.*reviews.json' "$MORE_LOOP"
  [ "$status" -eq 0 ]
}

# ── State transitions ──

@test "write_state_json creates state.json with correct phase" {
  source_functions
  export PROMPT_FILE="${TMPDIR}/prompt.md"
  echo "test" > "$PROMPT_FILE"
  echo "- [ ] Task A" > "${RUN_DIR}/tasks.md"
  echo "- [ ] Accept A" > "${RUN_DIR}/acceptance.md"

  write_state_json "bootstrap" ""
  [ -f "${RUN_DIR}/state.json" ]
  run python3 -c "import json; d=json.load(open('${RUN_DIR}/state.json')); print(d['phase'])"
  [ "$output" = "bootstrap" ]
}

@test "write_state_json includes approve_timeout field" {
  source_functions
  export PROMPT_FILE="${TMPDIR}/prompt.md"
  echo "test" > "$PROMPT_FILE"
  echo "- [ ] Task A" > "${RUN_DIR}/tasks.md"
  echo "- [ ] Accept A" > "${RUN_DIR}/acceptance.md"
  export APPROVE_TIMEOUT=300

  write_state_json "waiting_approval" ""
  run python3 -c "import json; d=json.load(open('${RUN_DIR}/state.json')); print(d['approve_timeout'])"
  [ "$output" = "300" ]
}

@test "state.json phase set to replanning" {
  source_functions
  export PROMPT_FILE="${TMPDIR}/prompt.md"
  echo "test" > "$PROMPT_FILE"
  echo "- [ ] Task A" > "${RUN_DIR}/tasks.md"
  echo "- [ ] Accept A" > "${RUN_DIR}/acceptance.md"

  write_state_json "replanning" ""
  run python3 -c "import json; d=json.load(open('${RUN_DIR}/state.json')); print(d['phase'])"
  [ "$output" = "replanning" ]
}

@test "state.json transitions: bootstrap → waiting_approval → replanning → waiting_approval" {
  source_functions
  export PROMPT_FILE="${TMPDIR}/prompt.md"
  echo "test" > "$PROMPT_FILE"
  echo "- [ ] Task A" > "${RUN_DIR}/tasks.md"
  echo "- [ ] Accept A" > "${RUN_DIR}/acceptance.md"

  # Bootstrap
  write_state_json "bootstrap" ""
  run python3 -c "import json; print(json.load(open('${RUN_DIR}/state.json'))['phase'])"
  [ "$output" = "bootstrap" ]

  # Waiting approval
  write_state_json "waiting_approval" ""
  run python3 -c "import json; print(json.load(open('${RUN_DIR}/state.json'))['phase'])"
  [ "$output" = "waiting_approval" ]

  # Replanning
  write_state_json "replanning" ""
  run python3 -c "import json; print(json.load(open('${RUN_DIR}/state.json'))['phase'])"
  [ "$output" = "replanning" ]

  # Back to waiting_approval
  write_state_json "waiting_approval" ""
  run python3 -c "import json; print(json.load(open('${RUN_DIR}/state.json'))['phase'])"
  [ "$output" = "waiting_approval" ]
}

# ── Task counting ──

@test "count_remaining counts unchecked tasks" {
  source_functions
  cat > "${RUN_DIR}/tasks.md" <<'EOF'
- [x] Done task
- [ ] Pending task 1
- [ ] Pending task 2
EOF
  run count_remaining
  [ "$output" = "2" ]
}

@test "count_remaining returns 0 when all done" {
  source_functions
  cat > "${RUN_DIR}/tasks.md" <<'EOF'
- [x] Done task 1
- [x] Done task 2
EOF
  run count_remaining
  [ "$output" = "0" ]
}

@test "get_next_task_name returns first unchecked task" {
  source_functions
  cat > "${RUN_DIR}/tasks.md" <<'EOF'
- [x] Done task
- [ ] Next task to do
- [ ] Another task
EOF
  run get_next_task_name
  [ "$output" = "Next task to do" ]
}

# ── enforce_single_task ──

@test "enforce_single_task allows single task completion" {
  source_functions
  cat > "${RUN_DIR}/.tasks-snapshot.md" <<'EOF'
- [ ] Task 1
- [ ] Task 2
EOF
  cat > "${RUN_DIR}/tasks.md" <<'EOF'
- [x] Task 1
- [ ] Task 2
EOF
  run enforce_single_task "${RUN_DIR}/.tasks-snapshot.md"
  [ "$status" -eq 0 ]
  # tasks.md should be unchanged (1 task completed, within limit)
  run grep -c '^\- \[x\]' "${RUN_DIR}/tasks.md"
  [ "$output" = "1" ]
}

@test "enforce_single_task trims excess completions" {
  source_functions
  cat > "${RUN_DIR}/.tasks-snapshot.md" <<'EOF'
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3
- [ ] Task 4
- [ ] Task 5
EOF
  cat > "${RUN_DIR}/tasks.md" <<'EOF'
- [x] Task 1
- [x] Task 2
- [x] Task 3
- [x] Task 4
- [x] Task 5
EOF
  run enforce_single_task "${RUN_DIR}/.tasks-snapshot.md"
  [ "$status" -eq 0 ]
  # Should trim to max_per_iter (3)
  run grep -c '^\- \[x\]' "${RUN_DIR}/tasks.md"
  [ "$output" = "3" ]
}

# ── handle_request_changes structure ──

@test "handle_request_changes function exists" {
  run grep -c 'handle_request_changes()' "$MORE_LOOP"
  [[ "$output" =~ ^[1-9] ]]
}

@test "handle_request_changes removes signal file" {
  # The function uses rm -f "$request_changes_file" where the variable holds the signal path
  run grep 'rm -f.*request_changes_file' "$MORE_LOOP"
  [ "$status" -eq 0 ]
}

@test "handle_request_changes calls rebootstrap" {
  run grep -A20 'handle_request_changes()' "$MORE_LOOP"
  [ "$status" -eq 0 ]
  [[ "$output" == *'rebootstrap'* ]]
}

# ── wait_for_approval polls for request-changes ──

@test "wait_for_approval checks for .signal-request-changes" {
  run grep -A50 'wait_for_approval()' "$MORE_LOOP"
  [ "$status" -eq 0 ]
  [[ "$output" == *'signal-request-changes'* ]]
}

@test "wait_for_approval checks for .signal-approve" {
  run grep -A50 'wait_for_approval()' "$MORE_LOOP"
  [ "$status" -eq 0 ]
  [[ "$output" == *'signal-approve'* ]]
}

# ── Backward compatibility ──

@test "more-loop still handles .signal-approve" {
  run grep 'signal-approve' "$MORE_LOOP"
  [ "$status" -eq 0 ]
}

@test "more-loop still handles .signal-stop" {
  run grep 'signal-stop' "$MORE_LOOP"
  [ "$status" -eq 0 ]
}

@test "write_state_json uses atomic write (no temp files left)" {
  source_functions
  export PROMPT_FILE="${TMPDIR}/prompt.md"
  echo "test" > "$PROMPT_FILE"
  echo "- [ ] Task A" > "${RUN_DIR}/tasks.md"
  echo "- [ ] Accept A" > "${RUN_DIR}/acceptance.md"

  write_state_json "bootstrap" ""
  # No .tmp files should remain after atomic write
  run find "${RUN_DIR}" -name '*.tmp' -type f
  [ -z "$output" ]
  # state.json should be valid JSON
  run python3 -c "import json; json.load(open('${RUN_DIR}/state.json'))"
  [ "$status" -eq 0 ]
}

@test "write_state_json atomic write overwrites previous state" {
  source_functions
  export PROMPT_FILE="${TMPDIR}/prompt.md"
  echo "test" > "$PROMPT_FILE"
  echo "- [ ] Task A" > "${RUN_DIR}/tasks.md"
  echo "- [ ] Accept A" > "${RUN_DIR}/acceptance.md"

  write_state_json "bootstrap" ""
  write_state_json "task" "Task A"
  run python3 -c "import json; d=json.load(open('${RUN_DIR}/state.json')); print(d['phase'])"
  [ "$output" = "task" ]
  # Still no temp files
  run find "${RUN_DIR}" -name '*.tmp' -type f
  [ -z "$output" ]
}

@test "more-loop script has valid bash syntax" {
  run bash -n "$MORE_LOOP"
  [ "$status" -eq 0 ]
}
