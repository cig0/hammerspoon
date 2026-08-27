# Agent Instructions

This file defines reusable, model-agnostic working principles. Keep
language-, framework-, tool-, and repository-specific directives in the
adjacent `AGENTS-REPOSITORY.md`.

The standard instruction filename is `AGENTS.md`. A repository-level
`AGENTS.md` may route agents to this source file and its companion when they
live under an asset directory.

## Instruction Discovery

- Before starting work, read the adjacent `AGENTS-REPOSITORY.md` when it exists.
- Read applicable instruction files from the repository root down to the files
  in scope. In each directory, `AGENTS.override.md` takes precedence over
  `AGENTS.md`.
- Treat instructions as additive. Explicit user instructions take precedence
  over repository files; among repository files, the closest applicable file
  wins on conflicts.
- Read documents explicitly required by an applicable instruction file before
  changing the area they govern.

## Engineering Principles

- When principles conflict, prioritize them in this order: KISS, readability,
  ergonomics, performance, lean implementation, DRY, YAGNI, and widely adopted
  community standards.
- Use as few abstractions as possible. Prefer explicit naming and visible
  behavior.
- Preserve object agency: each object should own its state, behavior, and
  visible output. Do not make one object encode hidden decisions for another
  object when the boundary can be explicit.
- Prefer semantic, native values for internal implementation state. Preserve
  external protocol values exactly as expected by their consumers.
- Follow existing patterns and ownership boundaries. Keep changes scoped to the
  request and avoid unrelated refactors.

## Scope and Authorization

- Answer the exact request first. Do not expand scope unless the user asks or a
  directly affected boundary must be inspected for correctness.
- For review, explanation, status, or diagnosis requests, remain read-only
  unless the user also asks for implementation.
- For change or build requests, make the necessary in-scope edits and run
  proportional checks. Do not repeatedly ask for confirmation for ordinary,
  reversible implementation steps.
- Ask a concise clarifying question only when a reasonable assumption could
  materially change the result, cross the requested boundary, or require new
  authority.
- State non-obvious assumptions that affect the result.
- Use read-only inspection freely. Do not contact external services or create
  externally visible changes unless the request authorizes that workflow.

## Working State and Change Protection

- Before editing, inspect the current workspace state and any local changes that
  could be affected.
- Re-read a file from disk before editing it if its content may have changed
  since it was last read.
- Treat the current workspace state as authoritative when reconciling changes.
- Never revert, overwrite, delete, or discard existing user changes without
  explicit confirmation.
- Do not classify unexpected local changes as noise. They may have been made by
  the user alongside the current work.
- Never perform destructive, irreversible, privileged, or system-wide actions
  without explicit approval.
- Never install packages outside a project-local or sandboxed environment
  without explicit approval.

## Failure Handling

- Never continue silently after a task-relevant failure, unexpected result, or
  ambiguous check.
- First distinguish a product or code failure from an operational mistake such
  as a typo, stale path, wrong output shape, or unsupported command option.
- Correct a harmless operational mistake and rerun the same verification
  question. Treat it as resolved only when the corrected command answers that
  question satisfactorily.
- For environment limitations such as a missing optional tool, look for a
  non-destructive local alternative that preserves the same validation
  boundary. Do not install system-wide dependencies without approval.
- Stop and request direction when the failure exposes broken code outside the
  requested scope, requires destructive recovery, needs additional authority,
  or leaves correctness ambiguous after safe investigation.
- Report unresolved failures and any resolved operational failure that affected
  verification. Documented non-error exit statuses need no special handling.

## Verification and Delivery

- Check every changed file after editing to ensure it is correct and nothing is
  broken.
- Run the relevant focused checks for the files and behavior changed.
- Inspect the final diff for unrelated edits, accidental generated-file or lock
  churn, stale names, and incomplete wiring.
- Report checks that passed, were not run, or could not be completed.
- Never commit, publish, or otherwise make changes externally visible unless
  the user explicitly asks.
