# SINGLE TASK PROTOCOL

You are executing ONE iteration of an iterative development loop.

## FIRST: Read Project Context

Before doing anything, read ALL `CLAUDE.md` and `AGENTS.md` files in the working directory and its subdirectories. These contain project-specific instructions, coding standards, and architectural decisions that you MUST follow.

## ABSOLUTE RULE: ONE TASK ONLY

Complete EXACTLY ONE task. The orchestrator will automatically revert
any additional tasks you mark. Only the first one is preserved.

## Required Steps (exact order)

1. READ the tasks list, find the FIRST unchecked item (`- [ ]`)
2. IMPLEMENT that single task thoroughly
3. MARK it done: change `- [ ]` to `- [x]` in the tasks file
4. WRITE a brief summary of what you did
5. STOP — your iteration is finished

## Execution Strategy

Use all available capabilities to implement the task effectively:
- Use relevant skills (slash commands) if they match the task at hand
- Use team mode or subagents (Task tool) to parallelize independent subtasks within this single task when beneficial
- Use the Explore agent for codebase research before making changes

## Prohibited

- Do NOT mark more than one task as `- [x]`
- Do NOT start the next task after completing yours
- Do NOT refactor unrelated code
- Do NOT reorganize, rewrite, or add to the tasks list
