---
name: more-loop-prompt
description: Create a prompt.md spec file for use with the more-loop iterative development script
disable-model-invocation: true
argument-hint: "[run-name]"
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion
---

# Create a more-loop prompt file

You are helping the user create a **prompt.md** spec file for use with `more-loop`, an iterative development script that wraps the `claude` CLI.

## How more-loop uses this file

1. **Bootstrap phase** — Claude reads the prompt file and generates:
   - `acceptance.md` — checklist of acceptance criteria (definition of done)
   - `tasks.md` — checklist of atomic implementation steps
2. **Task iterations** — Claude picks one task at a time and implements it
3. Each iteration is a **fresh `claude -p` process** with no shared context — the prompt file is the only source of truth for intent

## What makes a good more-loop prompt

A good prompt file should be **self-contained** and include:

- **What to build** — clear description of the feature, tool, or change
- **Context** — relevant codebase info, existing patterns, tech stack
- **Constraints** — language, framework, style, performance requirements
- **Scope boundaries** — what is explicitly out of scope
- **Examples** — sample inputs/outputs, API shapes, UI behavior

It should NOT include:
- Step-by-step implementation instructions (more-loop generates those)
- Acceptance criteria checklists (more-loop generates those too)
- Vague or open-ended goals ("make it better")

## Your process

1. **Ask the user** what they want to build. If `$ARGUMENTS` was provided, use it as the topic name.
2. **Ask clarifying questions** to fill gaps — scope, constraints, tech stack, existing code context. Ask at most 3 rounds of questions. Be specific: offer choices rather than open-ended questions where possible.
3. **Scan the codebase** if relevant — look at existing patterns, tech stack, directory structure to add concrete context to the prompt.
4. **Write the prompt file** in markdown with these sections:

```markdown
# <Title>

## Overview
<1-3 sentences: what to build and why>

## Context
<Relevant codebase info, tech stack, existing patterns>

## Requirements
<Bulleted list of specific, testable requirements>

## Constraints
<Language, framework, style, performance, compatibility>

## Out of Scope
<What NOT to do>

## Examples
<Sample inputs/outputs, API shapes, UI mockups — if applicable>
```

5. **Write the file** to the output path determined below.

## Output path

Files are organized under `.more-loop/runs/<run-name>/`:

1. **Determine the run name**: Use `$ARGUMENTS` if provided (as a slug, e.g., `web-dashboard`). Otherwise, derive a short kebab-case slug from the topic the user described (e.g., "Add auth system" → `auth-system`).
2. **Create the directory**: `.more-loop/runs/<run-name>/`
3. **Write the file**: `.more-loop/runs/<run-name>/prompt.md`

If `$ARGUMENTS` looks like an explicit file path (contains `/` or ends in `.md`), respect it as-is instead of using the directory convention.
