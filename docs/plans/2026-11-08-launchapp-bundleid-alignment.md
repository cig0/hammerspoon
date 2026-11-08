# Plan: Align menu `launchApp` actions with bundleID (stable ID) — v2

**Date:** 2026-11-08 (v2 2026-11-08)  
**Scope:** `hammerspoon/Spoons/Gearbox` — menu data, Quick Launch, and `launchApp`/`openSiri` dispatch  
**Status:** Approved — implements user decisions: (1) Siri → new action type, (2) Safari web apps via optional bundleID, (3) conditional enforcement  
**Question addressed:** “shouldn't we also use the ID for the menu apps, instead of the name for the action variable?” — interpreted as: use `bundleID` as primary launch key in menu rows, aligning them with `hyperkeys.lua`.

## Decisions from user

1. **Siri:** switch to new dedicated action type (not `name=="Siri"` hack). Target: `{ type="openSiri" }`.
2. **Safari web app `cig0's World of Wonders` + existing `WhatsApp Web`:** keep `bundleID` **optional** — Safari web app bundleIDs are `com.apple.Safari.WebApp.<UUID>` ephemeral; `name`-only via `hs.application.launchOrFocus` is ergonomic and already proven (`comms.lua:20` `name="WhatsApp Web"` with spaces). Leave out if too complex is not needed — we support it via optional.
3. **Enforcement:** depends on #2. If Safari web apps dropped → make `bundleID` canonical/required for new `kind="application"` rows. Currently we keep optional per #2; strict mode deferred to Slice 4.

## 1. Interpretation and boundary

* **Not renaming menu `id`.** Menu `id` (`leader`, `finder`, `developer`, `comms`, …) is graph identity (`loader.lua:118-129` `^[%w_-]+$`). Confusing with app identity would break `loader.lua:validateDefinitions` parent resolution.
* **Approved to implement:** Align `launchApp` in `menus/*.lua` with existing `bundleID` support in `actions.lua`+`hyperkeys.lua`; keep `name` required fallback. Add `openSiri` as first-class type.

## 2. Verified current state (spike 2026-11-08)

### 2.1 Two launch paths, different shapes

**Quick Launch (`hyperkeys.lua` → `config.quickLaunch` → `runtime.dispatchQuickLaunch` → `actions.execute`)**
* `hyperkeys.lua:6-27` emits `{ name, bundleID? }` or `{ type="openMenu", menu }`; only Siri is `hyperkeys.lua:22` `{ name="Siri" }` (no bundleID).
* `validation.lua:232-287` validates tuple-list `[{key,target}]` and legacy map; for tables requires `name:match("%S")` + optional `bundleID:match("%S")` (`L253`, `L277`). No `openSiri` arm → would fail as “requires application name or openMenu target”.
* `runtime.lua:609-622` 3-way: `string` → `launchApp{name}`, `openMenu` → session, `table+name` → `launchApp{name,bundleID}`. Siri hits 3rd branch synthesizing `launchApp{name="Siri"}` → `actions.lua:154` intercept.
* `loader.lua:552-607` resolves labels: `openMenu` → `menu.title`, else `target.name` → `labels[key]` sorted `labels[a]:lower()` (`L603`). No `openSiri` label → “invalid target”.

**Menu rows (`menus/*.lua` → `loader.lua` → `actions.execute`)**
* All 27 rows in 8 files (`ai.lua:15`, `comms.lua:15,20`, `developer.lua:15-65` 11 rows, `leader.lua:14`, `macos.lua:21`, `photo-and-video.lua:15-25`, `web-browsers.lua:15-25`, `planner.lua:15,20`) are `name`-only, no `bundleID`.
* `menus/README.md:31` documents `{ type="launchApp", name="FooBar" }`; Actions table `L119` says `launchApp → launchOrFocus(name)` — stale vs `actions.lua:152-170` already doing bundleID-first.
* `actions.lua:22-37` validates `name` required, `bundleID` optional string; `L152-170` does `Siri` → `openSiri()` (`com.apple.campo` + AX focus `L111-141`), else `bundleID` → `launchOrFocusByBundleID` → `get(bundleID):activate` → `launchOrFocus(name)` → alert.

**Tests:** `tests/gearbox.lua:1609` `launchedApplication=="ForkLift"` via name-only; `L2392` mocks `hs.application.open("com.apple.campo")` for Siri.

### 2.2 Safari web app spike

* `comms.lua:20` `label="WhatsApp"` vs `name="WhatsApp Web"` proves `label` ≠ `name` and spaces are intentional; installed as `~/Applications/WhatsApp Web.app` `CFBundleIdentifier=com.apple.Safari.WebApp.<UUID>`, `CFBundleName="WhatsApp Web"`.
* `actions.execute:165-168` fallback `launchOrFocus(name)` handles `"cig0's World of Wonders"` verbatim — `'` and spaces legal, no shell escaping. UUID regenerates on re-add → `bundleID` ephemeral, `name` stable. Keep optional.
* No filtering in `loader.lua:27` `validKinds` or `runtime.lua`; no denylist.

### 2.3 Data flow

```
hyperkeys.lua → config.quickLaunch
 → init.lua Preferences → Loader.load(directory, config, Actions, menuDefinitions, theme)
   → loader.loadDefinitions(menus/*.lua) → validateDefinitions (actions.validate) → assembleMenus → menus[id].rows + quickLaunchKeys/Labels
 → Runtime.new → dispatchQuickLaunch / handleCharacter → Actions.execute → hud.show (label/key only)
```

`loader.copyTable:36-44` deep-copies preserving `bundleID` verbatim; no loader change needed for bundleID.

## 3. Target behavior

* `launchApp` = `{ type="launchApp", name: string (required), bundleID?: string (recommended) }`. `bundleID` primary when present.
* `openSiri` = `{ type="openSiri" }` (no fields; extra keys rejected). Closes menu like `launchApp` (`{close=true}`).
* Error states: `bundleID=""`/whitespace → fail at `Gearbox.start()` (location-aware); unknown bundleID → fallback `name` → alert `name`; `openSiri` with `name`/`bundleID` → validation fail; legacy Quick Launch string `"Safari"` still works.

## 4. Ownership

| Owner | Produces | File |
|-------|----------|------|
| Menu author | `menus/*.lua` `action` | `ai.lua`, `comms.lua`, `developer.lua`, `web-browsers.lua`, `photo-and-video.lua`, `macos.lua`, `planner.lua`, `leader.lua` |
| Quick Launch author | `hyperkeys.lua` targets | `hyperkeys.lua`, `config.lua:10` |
| `loader.lua` | `menus[id].rows`, `quickLaunchKeys/Labels` | `loader.lua:36-44,113-164,212-385,432-612` |
| `validation.lua` | `quickLaunch` config validation | `validation.lua:230-287` |
| `actions.lua` | `validate`+`execute` (bundleID-first, openSiri) | `actions.lua:22-37,108-171` |
| `runtime.lua` | `dispatchQuickLaunch` | `runtime.lua:609-622` |
| `hud.lua` | renders `label`/`key` | `hud.lua` |

## 5. Slices

### Slice 1 — Siri + validation hardening (no menu data change)

* `actions.lua`: add `elseif action.type=="openSiri" then return` in `validate` (reject extra keys), add `if action.type=="openSiri" then openSiri() return {close=true}` in `execute` near `openScratchpad`, remove `name=="Siri"` intercept `L154-155` (or keep deprecated shim if desired — recommended remove).
* `validation.lua`: both `isOrderedList` (`L238-263`) and legacy (`L265-286`) add `elseif target.type=="openSiri"` accepted form.
* `loader.lua:562-602`: add `elseif target.type=="openSiri" then labels[key]="Siri"` in both ordered/list branches.
* `runtime.lua:609-622`: add `elseif target and target.type=="openSiri" then endMenuSession() actions.execute{type="openSiri"}` before `target.name` branch.
* `hyperkeys.lua:22`: `{ key="s", target={ type="openSiri" } }`.

Verify: `lua tests/gearbox.lua "$(pwd)"` (update test `L2392` mock to expect openSiri path if needed).

### Slice 2 — Docs

* `menus/README.md:30-35,119-129`: shape `name`+`bundleID`, note Safari web app `name`-only; Actions table add `openSiri` and correct `launchApp` fallback chain.
* `README.md:123-147` hyperkeys example: tuple form already, clarify `bundleID` preferred.
* `actions.lua:1-6` header: mention `openSiri`.

### Slice 3 — Populate bundleIDs (data-only)

* All `menus/*.lua` app rows: add `bundleID` where verifiable (`mdls`/`osascript`), keep `name`. Leave `Delta` (no stable ID) and Safari web apps (`WhatsApp Web`, `cig0's World of Wonders`) as `name`-only with comment.
* Example: `{ label="Osaurus", action={ type="launchApp", name="Osaurus", bundleID="com.example.Osaurus" } }`.

### Slice 4 — Conditional enforcement (deferred)

* If Safari web apps stay → keep optional, add lint warning only.
* If dropped → make `bundleID` required for `kind="application"` + `launchApp` (error `requires bundleID`), allowlist only `openSiri`.

## 6. What stays unchanged

* `loader` discovery/sorting/dividers, `validation` key identity, `hud`/`theme`/`preferences`/`configuration_menu`/`scratchpad`, `init.lua` wiring, menu `id` namespace, `kind` grouping. New app = one table in one `menus/*.lua`.

## 7. Compatibility

* Backwards: `name`-only rows still work; legacy Quick Launch string still via `runtime:612`.
* Nix: `assets/docs/NIX.md` staged copy verbatim — no module change.
* Rollback: remove `bundleID` or revert `openSiri` → `launchApp{name="Siri"}` (if shim kept).

## 8. Validation

| Boundary | Check | Command |
|----------|-------|---------|
| Schema | `bundleID=""` fails, `openSiri` with `name` fails, `name`-only passes | `lua tests/gearbox.lua` |
| Loader | `copyTable` retains `bundleID` | inspect `runtime.menus.*.rows` |
| Runtime | `openSiri` → `hs.application.open("com.apple.campo")`, bundleID-first fallback | mock in `tests/gearbox.lua` |
| HUD | label/key unchanged | `rowVisualByLabel` |
| Nix | staged tree | `nix flake check` |
| Manual | Hyper `s` → Siri window, Safari web app name launch | `hs.reload()` |

## 9. Open questions resolved

* Siri: dedicated type `openSiri` (chosen).
* Safari web apps: optional `bundleID` supports `"cig0's World of Wonders"`; `bundleID` ephemeral UUID.
* Enforcement: optional now, strict only if Safari web apps dropped.

## 10. What this does not do

* No `name`→`id` rename, no registry, no `loader`/`runtime` generic refactor beyond `openSiri` label/dispatch.
