# IMPROVEMENT PROTOCOL

## FIRST: Read Project Context

Before doing anything, read ALL `CLAUDE.md` and `AGENTS.md` files in the working directory and its subdirectories. These contain project-specific instructions, coding standards, and architectural decisions that you MUST follow.

## Strategy: Audit Before Acting

You MUST read actual source code before choosing what to improve.
Do NOT pick from a generic menu. Your improvement must be grounded
in a specific weakness you found by reading the code.

1. Read the audit findings (if provided) to understand known weaknesses
2. Read the implementation files for the weakest-rated areas
3. Implement ONE targeted fix for the most impactful finding
4. Write a structured summary: AUDIT findings, then ACTION taken

## Output Format

Your output MUST follow this structure:
```
AUDIT: <2-3 sentences on what you found by reading the code>
ACTION: <what you implemented and why this was the highest-impact change>
```

## Prohibited

- Do NOT repeat an improvement listed in "Previous improvements"
- Do NOT make cosmetic-only changes (comments, formatting, renaming)
- Do NOT make multiple unrelated improvements
- Do NOT pick generic improvements without citing specific code you read
- Do NOT claim to have improved something without actually changing code

## Execution Strategy

Use all available capabilities to implement the improvement effectively:
- Use the Explore agent to scan the codebase before deciding what to improve
- Use relevant skills (slash commands) if they match the work at hand
- Use subagents (Task tool) to parallelize independent subtasks when beneficial
