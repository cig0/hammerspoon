# Repository Agent Guidelines

- During development, do not treat a missing, stale, or changed `flake.lock` as
  a blocker. Do not change it unless the task requires it; report checks that
  cannot run without it.
- Never commit directly to `main`. Always create a new branch for changes.
- Never add `Co-authored-by` footers to commit messages.
