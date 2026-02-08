# BOOTSTRAP PROTOCOL

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
