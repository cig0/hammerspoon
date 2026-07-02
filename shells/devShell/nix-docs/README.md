# Nix Docs

Self-contained devShell that dumps the Hammerspoon option catalog.

## What it is

This flake exports one devShell, `default`, that exposes `dump-hammerspoon-options`.
The command evaluates the upstream flake's `interfaces.homeManagerOptionDocs` and
turns the schema into a Markdown table.

## Where it comes from

- Source: `hammerspoon/flake.nix` → `interfaces.homeManagerOptionDocs { lib }`.
- Default flake ref: the enclosing `hammerspoon` repo, auto-detected via `git rev-parse --show-toplevel`.
- Default target: `hammerspoon/assets/docs/ALL-OPTIONS.md`.

## Where it goes

- Stdout by default.
- `--write` writes the default target (or a path you provide).

## Usage

From inside the hammerspoon checkout:

```bash
cd shells/devShell/nix-docs
nix develop

dump-hammerspoon-options                          # stdout
dump-hammerspoon-options --write                  # overwrite assets/docs/ALL-OPTIONS.md
dump-hammerspoon-options path:../.. --write       # explicit flake ref and write flag
```

The script takes positional arguments in any order: `[flake-ref] [target] [--write]`.
Only `--write` is special; everything else is matched positionally.

> **Note**: `--write` needs the flake ref to resolve to a writable checkout, so run it
> inside the hammerspoon repo or pass an explicit `path:<repo-root>` argument.
