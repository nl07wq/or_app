# AGENTS.md

# OR-APP Development Standard
Version: 1.0.1
Last Updated: 2026-07-19

---

# Git Rule

Before starting any task:

- Commit the current workspace.
- Never rely on Undo.
- Always rely on Git history for recovery.

---

# STOP Rule

If a task requires architectural changes:

STOP.

Explain why.

Wait for approval.

Never guess.

Never assume.

---

# Purpose

This repository contains the source code for **OR-APP (Operation Reboot Life OS)**.

Your role is to implement requested tasks while preserving the existing architecture.

Do not redesign the project unless explicitly instructed.

---

# Task Instructions

Before starting any implementation:

Read TASK_TEMPLATE.md.

Follow the current task exactly.

TASK_TEMPLATE.md defines:

- Task Type
- Editable Scope
- Protected Scope
- Requirements
- Definition of Done

If TASK_TEMPLATE.md conflicts with AGENTS.md:

STOP.

Explain why.

Wait for approval.

---

# Development Philosophy

- Preserve architecture.
- Preserve existing behavior.
- Minimize breaking changes.
- Prefer maintainability over unnecessary optimization.

---

# Architecture

The current architecture is intentional.

Do NOT:

- Introduce new architecture.
- Replace existing design patterns.
- Introduce new state management solutions.
- Add packages without approval.
- Replace the current folder structure.

---

# UI Rules

Always reuse existing OR-APP widgets whenever possible.

Preferred widgets:

- OperationCard
- OperationButton
- OperationTextField
- SectionHeader

Use Material Symbols only.

Do not use emoji.

Preserve the current UI style.

---

# Responsibility Separation Rule

Responsibility separation is NOT a goal.

Split files only when the overall maintenance cost is reduced.

Before splitting files, evaluate:

- Responsibility independence
- Maintainability
- Readability
- Future extensibility
- Reusability
- Management cost

Do NOT split files:

- Only because they become long.
- Only to reduce line count.
- If the original file does not become significantly simpler.
- If it creates unnecessary wrapper files.

Overall maintainability is always more important than file count.

---

# Scope Rules

Modify only files included in the Editable Scope.

Do not modify unrelated files.

Do not rename files unless instructed.

Do not move files unless instructed.

Implement the smallest complete solution within the Editable Scope.

Do not assume that implementation includes navigation, routing, repository, database, or dependency injection unless explicitly permitted by the Integration Requirements.

If implementation requires modifying files outside the Editable Scope:

STOP.

Explain why the additional files are required.

Wait for approval.

Do not expand the Editable Scope by yourself.

---

# Repository Rules

Do not modify Repository classes unless explicitly requested.

Do not modify database models unless explicitly requested.

Do not modify serialization logic unless instructed.

---

# Coding Rules

Follow the existing coding style.

Reuse existing widgets whenever possible.

Avoid duplicated logic.

Avoid duplicated code.

Avoid unnecessary abstraction.

Avoid unnecessary wrappers.

Keep implementations simple.

---

# Modification Rules

When modifying existing code:

- Replace the existing implementation.
- Remove obsolete code.
- Do not duplicate existing statements.
- Do not leave old and new implementations together.
- Keep every modified file in a compilable state.
- Never duplicate declarations.
- Never duplicate widgets.
- Never duplicate AppBar, Scaffold or class members.

---

# Development Rules

Before implementation:

- Understand the requested task.
- Check the existing implementation.
- Verify dependencies.
- Verify affected files.

Do not assume missing behavior.

If the requested implementation cannot be completed within the editable scope:

STOP.

Explain why.

Wait for approval.

---

# Verification Rules

Never consider a task complete unless verification succeeds.

If compilation or analysis cannot be completed:

- Report the limitation clearly.
- Do not assume success.
- Do not claim the implementation is fully verified.

---

# Review Rules

Before considering a task complete:

- Review the generated diff.
- Verify that only intended files were modified.
- Verify that no unrelated code was changed.
- Verify that no duplicate code exists.
- Verify that old implementations were removed.
- Verify that existing code was replaced, not duplicated.
- Verify that the resulting file compiles.

If unexpected modifications exist:

STOP.

Explain why.

Wait for approval.

---

# Before Finishing

Always verify:

- Compile errors
- Import errors
- Null safety
- Existing behavior
- UI consistency
- No unintended side effects
- No duplicate declarations
- No duplicate implementations

If compilation cannot be verified:

- Clearly state that verification was not completed.
- Do not claim the task is complete.

---

# Review Priority

Priority order:

1. Correctness
2. Existing behavior
3. Maintainability
4. Readability
5. Performance

---

# When Unsure

Never guess.

Never assume.

Ask before:

- Changing architecture
- Editing unrelated files
- Introducing new dependencies
- Modifying repository behavior
- Modifying data models
- Changing existing UI behavior

When uncertain:

STOP.

Explain the issue.

Wait for approval.

