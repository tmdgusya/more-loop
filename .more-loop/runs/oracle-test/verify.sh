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
