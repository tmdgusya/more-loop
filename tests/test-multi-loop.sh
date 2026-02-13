#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MULTI_LOOP="$SCRIPT_DIR/multi-loop"
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc (expected='$expected', actual='$actual')"
    FAIL=1
  fi
}

assert_contains() {
  local desc="$1" pattern="$2" text="$3"
  if echo "$text" | grep -qF -- "$pattern"; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc (pattern='$pattern' not found)"
    FAIL=1
  fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" text="$3"
  if echo "$text" | grep -qF -- "$pattern"; then
    echo "  FAIL: $desc (pattern='$pattern' found but should not be)"
    FAIL=1
  else
    echo "  PASS: $desc"
  fi
}

echo "=== Test: providers.json exists and is valid JSON ==="
test -f "$SCRIPT_DIR/providers.json"
assert_eq "providers.json exists" "0" "$?"
python3 -c "import json; json.load(open('$SCRIPT_DIR/providers.json'))" 2>/dev/null
assert_eq "providers.json is valid JSON" "0" "$?"

echo "=== Test: providers.json has required providers ==="
providers_output="$(python3 -c "
import json
d = json.load(open('$SCRIPT_DIR/providers.json'))
for name in d.get('providers', {}):
    print(name)
")"
assert_contains "has glm provider" "glm" "$providers_output"
assert_contains "has kimi provider" "kimi" "$providers_output"
assert_contains "has claude provider" "claude" "$providers_output"

echo "=== Test: each provider has 'command' field ==="
missing="$(python3 -c "
import json
d = json.load(open('$SCRIPT_DIR/providers.json'))
for name, cfg in d.get('providers', {}).items():
    if 'command' not in cfg:
        print(name)
")"
assert_eq "all providers have command" "" "$missing"

echo "=== Test: multi-loop exists and is executable ==="
test -x "$MULTI_LOOP"
assert_eq "script is executable" "0" "$?"

echo "=== Test: --help shows usage ==="
help_output="$("$MULTI_LOOP" --help 2>&1)"
assert_contains "shows usage" "Usage:" "$help_output"
assert_contains "shows --providers" "--providers" "$help_output"
assert_contains "shows --status" "--status" "$help_output"
assert_contains "shows --config" "--config" "$help_output"
assert_contains "shows --init" "--init" "$help_output"

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "All tests passed"
else
  echo "Some tests FAILED"
  exit 1
fi
