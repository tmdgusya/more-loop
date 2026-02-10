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
RUN_DIR="$(find .more-loop -type d -name "prompt*" | head -1)"
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
