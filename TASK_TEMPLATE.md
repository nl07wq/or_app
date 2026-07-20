# TASK_TEMPLATE.md

# OR-APP Task Template

Version: 1.2

Last Updated: 2026-07-20

---

# Purpose

TASK_TEMPLATE defines a single implementation task for Codex.

Every task must:

- Follow AGENTS.md
- Respect the Editable Scope
- Respect the Integration Requirements
- Produce a standardized completion report

TASK_TEMPLATE defines **what to implement**.

AGENTS.md defines **how to implement**.

---

# Task Type

Select one.

### Type A — Widget

Small UI or widget modification.

Editable Scope

1–3 files.

No architecture changes.

---

### Type B — Feature

Feature implementation or enhancement.

Editable Scope

One feature directory.

Architecture must remain unchanged.

---

### Type C — Architecture

Repository, Model, Database, Navigation,
or Architecture changes.

Requires explicit approval before implementation.

---

# Task ID

TASK-000

---

# Briefing

Explain this task for the Product Owner.

Describe:

- What changes
- Why it changes
- What the user will notice

Keep it short.

---

# Current Behavior

Describe the current implementation.

Explain the current problem.

---

# Desired Behavior

Describe the expected implementation.

Be explicit.

---

# Editable Scope

List every file Codex is allowed to modify.

Example

- lib/features/dashboard/
- lib/features/dashboard/widgets/

---

# Expected Modified Files

List the files expected to change.

Required

-

Optional

-

This section helps review the implementation.

Unexpected modified files should be treated as potential scope violations.

---

# Integration Requirements

Specify how far the implementation should be integrated.

Examples

☐ Create only the requested files.

☐ Replace existing implementation.

☐ Register routes.

☐ Update navigation.

☐ Update existing screens.

☐ Connect to Repository.

☐ Connect to Database.

☐ Add dependency injection.

☐ Remain isolated (no integration).

Additional Notes

-

---

# Protected Scope

Everything outside the Editable Scope.

Or explicitly list protected files.

---

# Requirements

- Follow AGENTS.md.
- Preserve existing architecture.
- Preserve existing UI unless explicitly requested.
- Replace existing implementation.
- Use existing shared widgets whenever possible.
- Do not duplicate code.
- Do not modify unrelated files.
- Do not perform unrelated refactoring.
- Necessary refactoring is allowed only when required to implement the requested feature.

---

# Definition of Done

Describe completion criteria.

Example

- Feature works correctly.
- Existing behavior is preserved.
- Only Editable Scope files were modified.
- No duplicate code.
- No compile errors.

---

# Review Checklist

Verify

- Only Editable Scope files were modified.
- Expected Modified Files match the implementation.
- No unrelated modifications exist.
- Existing code was replaced, not duplicated.
- No duplicate implementations remain.
- Existing behavior is preserved.
- Project compiles successfully.

---

# Notes

If implementation cannot be completed within the Editable Scope

STOP.

Explain why.

Wait for approval.

Never expand the scope yourself.

---

# Completion Report

When the task is complete, report:

## Summary

Briefly describe what changed.

---

## Modified Files

List every modified file.

Clearly distinguish:

Required

Optional

Unexpected

---

## Integration Status

Report whether the task changed

- Navigation
- Repository
- Database
- External Services

If no integration occurred, explicitly state that the implementation remains isolated.

---

## Known Limitations

Describe any intentional limitations.

Example

- Placeholder values
- Disabled buttons
- Dummy data

---

## Screenshot

For UI tasks

If a Flutter render target is available:

Include one screenshot.

Otherwise report

Screenshot unavailable.

Reason:

...

---

## Verification

Report

- flutter analyze
- dart analyze
- git diff --check

If any verification could not be completed

Explain why.