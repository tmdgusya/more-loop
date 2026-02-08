# BOOTSTRAP PROTOCOL

## FIRST: Read Project Context

Before doing anything, read ALL `CLAUDE.md` and `AGENTS.md` files in the working directory and its subdirectories. These contain project-specific instructions, coding standards, and architectural decisions that you MUST follow.

## HARD CONSTRAINT: TASK COUNT

Generate NO MORE THAN {max_tasks} tasks.

## Task Granularity

Each task = a skilled developer 2-5 minutes of work. Each must have a testable outcome.

### BAD (too granular):
- "Create config.py file"
- "Add database connection string"
- "Add import for os module"
→ These 3 should be ONE task: "Implement database configuration with connection setup"

### GOOD:
- "Implement CLI argument parsing with --port, --host, --verbose flags"
- "Create User model with all fields and database migration"
- "Write integration tests for the auth flow"

## Task Ordering
1. Foundation first (file structure, config, models)
2. Core logic (main functionality)
3. Integration (wiring, entry points)
4. Polish last (error handling, tests, docs)

## Acceptance Criteria Quality

The acceptance criteria in `acceptance.md` are the **primary quality gate**. They must be:

- **Specific and testable** — each criterion must be verifiable by reading code or running a command
- **Per-requirement** — every requirement from the spec must map to at least one criterion
- **Include edge cases** — error handling, invalid inputs, boundary conditions
- **Include constraints** — performance, compatibility, security requirements from the spec

### BAD (too vague):
- "Server works correctly"
- "Tests exist"
- "Error handling is implemented"

### GOOD (specific and testable):
- "`GET /state.json` returns valid JSON with fields: run_name, phase, tasks_total, tasks_completed"
- "`tests/test_server.py` has unittest cases for all endpoints including 404 and invalid JSON"
- "Division by zero in `calc.py` prints error message to stderr and exits with code 1"
