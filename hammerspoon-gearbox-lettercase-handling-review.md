# Gearbox letter-case handling — plan review and amended implementation plan

## Status and purpose

This document reviews `hammerspoon-gearbox-lettercase-handling.md` (referred to
throughout as the **original plan**, abbreviated **OP**) and produces an amended
implementation plan that resolves the ambiguities the OP leaves open. It is
intended to be read side by side with the OP, section by section, by a human or
another agent with no prior conversation history.

This document is a plan and review artifact. Like OP "Implementation sequence"
step 2, it does not by itself authorize code changes.

The review was performed on 2026-08-26 against the working tree. The OP claims
inspection at commit `9ac9ec4` on `main`; git state was not independently
verifiable during the review, so both documents' state claims must be
re-verified before editing. In every case that could be checked, the OP's
description of the current codebase was found to be accurate (see "Verified OP
claims" below).

Scope and style follow the repository's `AGENTS.md`: KISS first, minimal
abstractions, explicit ownership boundaries, no nix-related directives
(intentionally omitted here), Lua/Hammerspoon practices only.

## How to compare against the original plan

- OP sections are cited as `OP §<number>` (its "Proposed design" items 1-8) or by
  quoted section titles.
- Findings are numbered `F1`-`F11`. Each finding states its category from the
  review brief (over-engineering, performance, bug-inducing ambiguity,
  quality), severity, evidence, and a **Resolution** that the amended plan
  adopts.
- The **Decision register** (`D1`-`D10`) consolidates every behavioral decision
  an implementer must encode. Entries marked "adopt" restate an OP decision
  unchanged; the rest replace OP hedges with explicit rules.
- The amended plan reuses the OP's structure and only marks deltas. Anything
  not explicitly changed is adopted as written.
- The Findings section opens with an index table mapping each `F` ID to its
  category, severity, and the decision(s) that resolve it; read it first for a
  complete impact summary, then consult the bodies for evidence.

## Section disposition summary

| OP section                                  | Disposition                                                 |
| ------------------------------------------- | ----------------------------------------------------------- |
| Goal / Agreed product decisions 1-9         | Adopt unchanged                                             |
| Unresolved product decision (root `W` row)  | Adopt unchanged; still blocked on user input                |
| Current architecture and constraints        | Adopt; verified accurate against the code                   |
| OP §1 Classify activation keys centrally    | Adopt with fixes F7, F8/D8-D9                               |
| OP §2 Precompute per-menu character lookups | Adopt with fix F7a/D7 (footer exclusion)                    |
| OP §3 Session-scoped key-down event tap     | Adopt with fix F6/D6 (repeat semantics)                     |
| OP §4 Derive the character                  | **Supersede** with D1-D2 (default: no inversion)            |
| OP §5 Preserve modifier ergonomics          | Adopt with fixes F3/F4/F5 encoded as D3-D5                  |
| OP §6 Session vs modal lifecycle            | Adopt unchanged (best structural decision in the OP)        |
| OP §7 Secure Input handling                 | Adopt with D10 (tap re-verification on reuse)               |
| OP §8 Apply key convention in menu data     | Adopt unchanged                                             |
| Native behavior spike                       | Adopt; extend question set (see Phase 0)                    |
| Expected files list                         | Adopt; no additions                                         |
| Implementation sequence                     | Reorder/expand: see Phase comparison below                  |
| Regression and acceptance matrix            | Adopt; extend with deltas listed in Phase 6                 |
| Test harness changes                        | Adopt; extend (own early phase; `getKeyCode` double needed) |
| Risk review                                 | Superseded by the Decision register where it hedged         |
| Non-goals                                   | Adopt unchanged                                             |

---

## Verified OP claims (with code references)

| OP claim                                                               | Verified  | Evidence                                                                                                                                                                   |
| ---------------------------------------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 27 application rows across 9 named menu files                          | Yes       | agenda 3, ai 2, comms 2, developer 4, leader 5, macos 1, omni 2, photo-and-video 3, web-browsers 5 = 27 `launchApp` rows; `applications.lua` and `finder.lua` contain none |
| Web Browsers child entry is `key = "w"` on the root menu               | Yes       | `menus/web-browsers.lua` entry, parent `leader` (root, no `parent` field)                                                                                                  |
| `isHotkeyKey` validates via `hs.keycodes.map[key:lower()]`             | Yes       | `validation.lua` L129-135                                                                                                                                                  |
| `keyIdentity` lowercases names and canonicalizes `#<code>`             | Yes       | `validation.lua` L140-144                                                                                                                                                  |
| Loader rejects duplicates/reserved keys and creates one modal per menu | Yes       | `loader.lua` L163-169, L247-255, L407-412, L440-448                                                                                                                        |
| Runtime binds rows bare + configured modifiers via `bindFlexible`      | Yes       | `runtime.lua` L88-95; toggle skip is a case-insensitive `keyIdentity` comparison                                                                                           |
| Menu transition = exit current modal, enter target modal               | Yes       | `runtime.lua` L134-141                                                                                                                                                     |
| Scratchpad success exits menu; failure keeps menu for retry            | Yes       | `runtime.lua` L152-156; `scratchpad.lua` `show()` returns false on early failure                                                                                           |
| HUD renders explicit uppercase keys without HUD changes                | Yes       | `hud.lua` L18 (`keyDisplayNames` maps only `escape`/`return`), L150-152                                                                                                    |
| OP §1 "global-toggle conflict checks" exist as described               | Partially | The only such check is in `Runtime:bindFlexible` (`runtime.lua` L92-93), not in validation or the loader. See F5.                                                          |

Additional facts established during review and relied on below:

- `validateConfig` accepts `"shift"` as a `hotkey.modifiers` member
  (`validation.lua` L14-22). Default config is `{"alt", "cmd"}` + `"space"`
  (`config.lua` L6).
- Only arrow keys bind a repeat callback (`bindRepeating`, `runtime.lua`
  L101-104). All action rows bind with `repeatfn = nil`, so held keys on action
  rows fire once today.
- The terminal exit paths (`menu.modal:exit()` call sites) are exactly six:
  timeout timer (L63-73), global toggle handler (L283-292), `exit` action
  callback and `close = true` branch in `runAction` (L146-171), successful
  scratchpad handoff (L155), and `Runtime:stop()` (L316). OP §6's list of seven
  counts the Exit action separately; the count discrepancy is immaterial since
  all are enumerated.
- The test harness (`tests/gearbox.lua`) doubles have no `hs.eventtap.new`,
  `checkKeyboardModifiers`, or `isSecureInputEnabled` today; `hs.keycodes.map`'s
  `__index` only matches `^[a-z0-9]$` single characters; printable keys are
  driven via `menu.modal.bindings[key]()` (which stores only the _last_ binding
  registered for a key).

Hammerspoon API facts verified against current documentation
(<https://www.hammerspoon.org/docs/hs.eventtap.html> and
`hs.eventtap.event.html`):

- `hs.eventtap.new(types, fn)`: the callback's first return value `true`
  deletes (suppresses) the event; otherwise it propagates.
- `hs.eventtap:start()` returns the tap object, **not** a boolean — OP §7's
  post-`start()` `isEnabled()` verification is required and correct.
- `hs.eventtap.isSecureInputEnabled()` exists; while active, keyboard events
  cannot be intercepted at all.
- `hs.eventtap.checkKeyboardModifiers()` returns an **instantaneous poll** of
  state "at this instant" (its own docs' emphasis) and does include `capslock`.
- `event:getCharacters(clean)`: `clean = true` strips "key modifiers, other
  than Shift". The docs are **silent on Caps Lock** — hence F1.
- `event:getFlags()` documented keys are `cmd`, `alt`, `shift`, `ctrl`, `fn`.
  `capslock` is **not** documented there — hence D2's spike question.
- `event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat)` is
  non-zero for autorepeat key-downs.
- `event:getKeyCode()` returns the virtual keycode — needed for D5.

Assumptions the spike must confirm (not verifiable from docs alone):

- **A1**: `hs.hotkey` matching masks Caps Lock (and Fn) out — i.e., today
  `caps+w` fires a bare `{}, "w"` modal binding. The event-tap design must
  replicate this mask.
- **A2**: whether `getCharacters(true)` already includes Caps Lock's case
  effect for letters on the active layout.
- **A3**: whether `event:getFlags()`'s returned table can contain `capslock`
  on this Hammerspoon build.

---

## Findings

Index for scanning; each finding is detailed in the sections that follow.

| ID  | Finding                                                                             | Category                        | Severity      | Resolved by          |
| --- | ----------------------------------------------------------------------------------- | ------------------------------- | ------------- | -------------------- |
| F1  | OP §4's expected algorithm double-inverts Caps Lock case                            | bug-inducing ambiguity          | high          | D1                   |
| F2  | `checkKeyboardModifiers()` polls instantaneous state, not event state               | bug-inducing ambiguity          | medium        | D2                   |
| F3  | Fn in command state regresses chords accepted today                                 | bug-inducing ambiguity          | low-medium    | D3                   |
| F4  | `shift` as a configured modifier contradicts OP §5's two rules                      | bug-inducing ambiguity          | medium        | D4                   |
| F5  | Global-toggle skip under-specified and misattributed                                | bug-inducing ambiguity; quality | medium        | D5                   |
| F6  | "Ignore key-repeat events" permits a character-leak reading                         | bug-inducing ambiguity          | medium        | D6                   |
| F7  | Printable-ASCII contract holes: footer ownership; `isHotkeyKey` rejects punctuation | quality; ambiguity              | low-medium    | D7, D8               |
| F8  | Tap ownership model left undecided                                                  | over-engineering risk           | low           | D10                  |
| F9  | No further over-engineering found; keep the reserved-key case-split free via D9     | over-engineering                | informational | nothing to implement |
| F10 | Loop invariants must be precomputed, not recomputed per event                       | performance                     | low           | Task 4.1             |
| F11 | Poll-per-keystroke only as a spike-forced fallback                                  | performance                     | low           | D2                   |

### F1 — OP §4's "expected algorithm" is a probable double-inversion bug

- **Category:** bug-inducing ambiguity
- **Severity:** high
- **Where:** OP §4 steps 1-4; OP risk "Incorrect Caps Lock inversion".
- **Evidence:** `getCharacters(clean)` strips modifiers "other than Shift" and
  the documentation is silent on Caps Lock. Caps Lock is keyboard _state_ (like
  Shift), not a held modifier in the Command/Option/Control sense, so the
  produced character very likely already carries its effect. If so, OP §4 step
  3 ("invert the result's case when Caps Lock is active") computes
  `caps-on + w → event character W → invert → w`, which inverts the Goal's own
  matrix.
- The OP hedges correctly ("must be verified before encoding the inversion") but
  still presents the inversion as the _expected_ algorithm, which primes an
  implementer to write the bug first.

**Resolution (D1):** default to trusting the event. The normalization is:
`ch = event:getCharacters(true)`; accept only a single printable ASCII
character; look it up exactly. No inversion code exists unless the spike
proves Caps Lock is stripped from cleaned characters (A2), in which case
inversion applies to ASCII letters only, exactly once, with the spike matrix
quoted in a comment at the inversion site.

**Rationale:** the spike is the only source of truth here; the code should
encode the _observed_ contract, and the observed contract is overwhelmingly
likely to be "the character is already correct".

### F2 — `checkKeyboardModifiers()` is an instantaneous poll, not event state

- **Category:** bug-inducing ambiguity (+ minor performance, see F11)
- **Severity:** medium
- **Where:** OP §4 step 2.
- **Evidence:** the API documents it as modifiers "in effect _at this instant_".
  Inside a tap callback it can disagree with the event's own flags for queued
  events. `event:getFlags()`'s documented keys omit `capslock`, so per-event
  caps state may not exist through the documented API.

**Resolution (D2):** spike question A3 decides the source. If
`event:getFlags()` exposes `capslock`, use it (exact per-event state). If not,
`hs.eventtap.checkKeyboardModifiers().capslock` inside the callback is
acceptable and must carry a comment stating why it is safe: events and
callbacks serialize on the main runloop, so the poll is ordered with respect to
the event stream in practice. Either way the choice is made deliberately and
recorded, not discovered during debugging.

**Rationale:** eliminates a latent race-by-construction; keeps exactly one
documented source of caps state.

### F3 — Fn must not join "command state"

- **Category:** bug-inducing ambiguity (silent regression)
- **Severity:** low-medium
- **Where:** OP §5 ("command state: Command, Option, Control, and Fn").
- **Evidence:** `hs.hotkey` matching ignores Fn; today `fn+w` with a menu open
  fires row `w`. Under OP §5's rule the chord would be rejected and the
  character typed into the underlying application.

**Resolution (D3):** command state is `flags ∩ {cmd, alt, ctrl}` only. Fn is
masked out entirely (current-behavior parity, pending spike confirmation of A1).
Shift and Caps Lock never participate in acceptance.

**Rationale:** the feature must not narrow chords that Gearbox already accepts;
OP's own constraint ("This must remain true when the user holds the configured
Gearbox activation modifiers") extends to not regressing modifier masks that
`hs.hotkey` ignores today.

### F4 — `shift` in `hotkey.modifiers` conflicts with OP §5's two rules

- **Category:** bug-inducing ambiguity
- **Severity:** medium (config-reachable corner; default config unaffected)
- **Where:** OP §5's separation of "case-related state" (Shift) from "command
  state".
- **Evidence:** `validateConfig` accepts `"shift"` in `hotkey.modifiers`
  (`validation.lua` hotkey list). If configured, Shift is simultaneously case
  state and command state, and OP §5's "exactly equal to
  `config.hotkey.modifiers`" comparison can never succeed.

**Resolution (D4):** acceptance is computed over `{cmd, alt, ctrl}` masks only:
accept iff `cmdState == {}` **or**
`cmdState == normalize(config.hotkey.modifiers) ∩ {cmd, alt, ctrl}`, where
`normalize` folds aliases (`option → alt`, `command → cmd`, `control → ctrl`)
and deduplicates. Both sets are precomputed once (see F10). Shift therefore
always acts as case input and never invalidates acceptance — which satisfies OP
§5's first rule uniformly. A configured `"shift"` remains accepted at
validation; it simply routes through case semantics (chord + letter produces
the shifted character), which is the feature's whole point.

**Rationale:** one comparison rule, no config-contract change, no special cases,
and it degrades coherently for shift-bearing configurations instead of
dead-locking them.

### F5 — The global-toggle skip is under-specified and misattributed

- **Category:** bug-inducing ambiguity; quality (wrong location attribution)
- **Severity:** medium
- **Where:** OP §1 ("Apply the same identity consistently to … global-toggle
  conflict checks"); OP §5's final sentence ("Preserve the existing rule …").
- **Evidence:** the only existing check is `Runtime:bindFlexible`'s
  case-insensitive `keyIdentity` comparison (`runtime.lua` L92-93). Once
  character rows are no longer modal-bound, that skip disappears and must be
  re-created in the tap — but it cannot be character-based, because
  `config.hotkey.key` is a key _name_ (`"space"`) while the tap sees
  _characters_ (`" "`).

**Resolution (D5):** the tap passes the event through (no dispatch, no consume)
iff both hold:
`event:getKeyCode() == resolvedGlobalKeyCode` **and**
`flags ∩ {cmd, shift, ctrl, alt} ⊇ normalize(config.hotkey.modifiers)`.
`resolvedGlobalKeyCode` is precomputed once: `config.hotkey.key` resolved
through `hs.keycodes.map` for names, or parsed numerically for raw `#<code>`
strings.

This reproduces today's behavior in all sub-cases (verified against
`bindFlexible` + `hs.hotkey` exact-match semantics):

| Input (row key `g`, toggle `alt+cmd+g`) | Today                                                     | Under D5                           |
| --------------------------------------- | --------------------------------------------------------- | ---------------------------------- |
| bare `g`                                | row fires (bare binding kept)                             | row fires                          |
| `alt+cmd+g`                             | toggle closes (mods binding skipped)                      | toggle closes                      |
| `alt+cmd+shift+g`                       | dead key (toggle exact-match fails; mods binding skipped) | passes through, nothing dispatches |
| `caps+alt+cmd+g`                        | toggle closes (caps masked)                               | passes through; toggle closes      |

Note D5 is keycode-based, so it also covers a hypothetical row `G` sharing the
toggle's physical key: chord + that key never dispatches, keeping the toggle
unambiguous by construction.

**Rationale:** converts a hand-wave into a testable rule that provably matches
current behavior.

### F6 — "Ignore key-repeat events" has a dangerous reading

- **Category:** bug-inducing ambiguity
- **Severity:** medium
- **Where:** OP §3's repeat sentence; OP risk matrix does not cover it.
- **Evidence:** "ignore" read as _pass through_ would leak repeated characters
  into the underlying application when a matched key is held. Today
  `hs.hotkey` consumes repeats of a matched hotkey and calls nothing, because
  every action row binds with `repeatfn = nil` (only arrows use
  `bindRepeating`). The OP's hedge ("unless a live comparison proves the
  current modal behavior intentionally repeats") is backwards: the current code
  already proves no-repeat for action rows.

**Resolution (D6):** if `keyboardEventAutorepeat` is non-zero: for a _matched_
character, return `true` (consume, no dispatch — parity with today's swallowed
repeats); for an _unmatched_ character, pass through (parity with unbound keys
today). The tap still evaluates character and acceptance rules _before_ the
repeat check so "matched" is well-defined.

**Rationale:** exact behavioral parity with the modal implementation that the
feature replaces, using only documented APIs. No hedge remains.

### F7 — The "single printable ASCII character" contract has two holes

- **Category:** quality (contract coherence); bug-inducing ambiguity (F7a)
- **Severity:** low-medium
- **Where:** OP §1 boundary; OP §2 row selection.

**F7a — Footer rows.** OP §2 says "only non-divider rows classified as
character keys enter this table". Footer rows are non-divider and carry
`kind = "footer"` with `config.navigation.cancelKey`. With the default
`cancelKey = "escape"` this is safe, but a printable `cancelKey` (valid per
`validateConfig`) would put the footer in the tap _and_ in a bare-only modal
binding — double ownership — and would make the footer triggerable with the
full modifier chord, whereas today it is `bindBare`-only (`runtime.lua`
L220-224).

**Resolution (D7):** rows with `kind == "footer"` are never
character-classified and remain modal-bound bare-only, regardless of key value.
Navigation bindings (`up`/`down`/activate/cancel) are always modal-owned. The
convention documentation then states activation characters apply to item and
child-menu rows.

**F7b — Character validation.** `isHotkeyKey` checks `hs.keycodes.map`; `!` and
most punctuation are not key names, so the OP §1 boundary ("a single printable
ASCII character is a character activation key") is unreachable for those
characters — the loader would reject them before classification.

**Resolution (D8):** `isHotkeyKey` accepts, in order: a single printable ASCII
character (bytes 0x21-0x7E; space excluded — the named key `"space"` covers
it); a `#<digits>` keycode; or `hs.keycodes.map[key:lower()]`. `keyIdentity`
becomes: single printable ASCII → exact (letters keep case); `#<digits>` →
numeric canonical; anything else → lowercased (D9, adopted from OP §1).

**Rationale:** D7 removes the only ownership overlap between tap and modal; D8
makes the stated contract actually implementable. Current menu data uses
letters only, so both fixes are contract completions, not behavior churn.

### F8 — Tap ownership model must be decided, not deferred

- **Category:** over-engineering risk / unresolved decision
- **Severity:** low
- **Where:** OP acceptance matrix: "Repeated Gearbox sessions reuse or recreate
  the tap according to the chosen simple ownership model without accumulating
  native objects."
- **Evidence:** no ownership model is chosen anywhere in the OP.

**Resolution (D10):** exactly one `hs.eventtap` per `Runtime`, created during
`Runtime:start()` alongside the global hotkey; `:start()`/`:stop()` per
session only; never recreated mid-runtime; `endSession()` and `Runtime:stop()`
stop it; every `beginSession()` re-verifies `isEnabled()` on the reused tap
(same code path as first-open verification, so it is free).

**Rationale:** creating/tearing down native tap objects per session adds churn
and leak surface for zero benefit; re-verification on every begin also covers
the rare case of macOS disabling a tap by timeout (the OP otherwise leaves a
mid-session disabled tap unhandled — accepted as a non-goal, with this cheap
guarantee in its place).

### F9 — No other over-engineering found

- **Category:** over-engineering
- **Severity:** informational

The session-scoped tap, mutually exclusive input ownership, precomputed
lookups, convention-not-inference, no new config, no new module, no watchers,
and the refusal to restart the tap on menu transitions are all justified and
minimal. The one place to _watch_ during implementation is OP §1's reserved-key
case-split ("reserved single-character navigation keys reserve only the
matching case"): it falls out of D9 for free, so keep it as a test expectation,
not as bespoke logic.

### F10 — Precompute loop invariants once

- **Category:** performance
- **Severity:** low (clarity as much as speed)
- **Evidence / Resolution:** `normalize(config.hotkey.modifiers)`,
  its `{cmd, alt, ctrl}` intersection, and `resolvedGlobalKeyCode` are
  invariants of the runtime; compute them in `Runtime:start()`, not per event.
  The hot path then is, per keyDown, exactly: mask flags, one
  `getCharacters(true)`, one table lookup, one `runAction` on match.

**Rationale:** tap callbacks must be fast by construction; precomputation makes
the cost obvious from reading the code, which matters more than the
(microscopically small) saved time.

### F11 — Poll-per-keystroke only if the spike forces it

- **Category:** performance
- **Severity:** low
- **Where:** OP §4 step 2 (see F2).

**Resolution:** if A3 shows `getFlags()` carries `capslock`, the callback makes
zero poll calls; the poll variant (single `checkKeyboardModifiers()` call per
accepted-shape event) is acceptable as the fallback. Dispatch itself stays
synchronous inside the callback — identical threading model to today's hotkey
callbacks. Deferring `runAction` via a zero-delay timer would complicate the
suppression contract for no measurable gain and is explicitly rejected.

---

## Decision register

| ID  | Decision                                                                                                                                                                                                   | Supersedes / grounds             |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| D1  | Trust the event: `ch = getCharacters(true)`; accept single printable ASCII only; exact lookup. Inversion exists only if A2 proves caps is stripped from cleaned characters, then ASCII letters only, once. | OP §4 steps 3-4                  |
| D2  | Caps source = `event:getFlags().capslock` if A3 confirms it exists; else `hs.eventtap.checkKeyboardModifiers().capslock` with a runloop-ordering comment.                                                  | OP §4 step 2                     |
| D3  | Command state = `flags ∩ {cmd, alt, ctrl}`. Fn masked out (A1 parity). Shift/Caps excluded always.                                                                                                         | OP §5 command-state list         |
| D4  | Accept iff `cmdState == {}` or `cmdState == normalize(config.hotkey.modifiers) ∩ {cmd, alt, ctrl}`; both precomputed.                                                                                      | OP §5 acceptance rule            |
| D5  | Toggle skip: pass through iff `event:getKeyCode() == resolvedGlobalKeyCode` and `flags ∩ {cmd, shift, ctrl, alt} ⊇ normalize(config.hotkey.modifiers)`. Both operands precomputed.                         | OP §5 last sentence; fixes F5    |
| D6  | Autorepeat: matched → consume, no dispatch; unmatched → pass through.                                                                                                                                      | OP §3 repeat sentence            |
| D7  | `kind == "footer"` rows and navigation bindings are never character-classified; they remain modal-only (footer bare-only).                                                                                 | OP §2 scope                      |
| D8  | `isHotkeyKey` additionally accepts single printable ASCII (0x21-0x7E, space excluded).                                                                                                                     | OP §1 gap F7b                    |
| D9  | `keyIdentity`: single printable ASCII → exact; `#<digits>` → numeric canonical; else → lowercase. (Adopt OP §1 boundary as-is.)                                                                            | OP §1                            |
| D10 | One tap per Runtime, created in `Runtime:start()`; start/stop per session; `isEnabled()` re-verified on every `beginSession()`; never recreated mid-runtime.                                               | OP "reuse or recreate" open item |

## Amended implementation plan (with rationale per task)

### Phase 0 — Ground truth

**Task 0.1 — Verify state and authorization.** Re-check git status and the
guidance files; confirm explicit go-ahead. _Rationale: OP step 1-2 and
`AGENTS.md` working-state rules. Neither document's state claims were
independently verifiable at review time._

**Task 0.2 — Run the native spike (uncommitted).** In the Hammerspoon console,
record for `w` on the active layout across Caps × Shift × {no modifiers,
configured modifiers}: `getCharacters(false)`, `getCharacters(true)`, full
`getFlags()` table (answer A3), and `checkKeyboardModifiers()`. Also verify A1
(caps/mask behavior of existing modal bindings, observable by whether caps+w
fires a bare-bound modal key today), tap `start()`/`stop()`/`isEnabled()`
stability across repeated sessions, suppression of a matched event, and
autorepeat property values. Record the matrix verbatim in a comment beside the
new test helper (Task 1.1). _Rationale: A1-A3 decide D1, D2, D3's parity claim,
and D6's mock shape. The OP's spike section is adopted; this only adds the
explicitly enumerated questions._

**Task 0.3 — Decision gate.** Encode D1-D2 from spike evidence before writing
any production input code. _Rationale: F1/F2 — the two highest-risk findings —
must be resolved before code, not during review of the diff._

### Phase 1 — Test harness doubles

**Task 1.1 — Extend the mocked `hs` boundary in `tests/gearbox.lua`.** Add
`hs.eventtap.new()` (records its callback; double supports
`start`/`stop`/`isEnabled` and tracks an enabled flag), `event.types.keyDown`,
`event.properties.keyboardEventAutorepeat`, controllable
`checkKeyboardModifiers()` and `isSecureInputEnabled()`, and event doubles with
`getCharacters`, `getFlags`, `getKeyCode`, and `getProperty`. Provide one
helper, e.g. `sendKeyEvent{char, shift, caps, mods, autorepeat}`, that invokes
the recorded tap callback. _Rationale: additive only; the existing suite stays
green while production code lands incrementally. The OP's harness section is
adopted; `getKeyCode` is added because D5 needs it._

**Task 1.2 — Harness detail: distinct keycodes.** The current
`hs.keycodes.map` mock returns the same code (`1`) for every letter via
`__index`. Event doubles must carry distinct keycodes per key (the double can
accept the keycode explicitly) so D5's toggle-skip tests cannot vacuously pass.
_Rationale: otherwise every letter event matches `resolvedGlobalKeyCode` in the
mock and silently masks real bugs._

**Constraint (adopted from OP):** the mock validates Gearbox's decision logic
only; it must not attempt to reproduce AppKit character translation.

### Phase 2 — Identity foundation (`validation.lua`)

**Task 2.1 — Add `isCharacterKey(key)`:** true iff `key` is a single printable
ASCII character (0x21-0x7E). Document the space exclusion. _Rationale: one
small pure function owned by validation; consumed by loader and runtime.
KISS/readability first._

**Task 2.2 — Extend `keyIdentity` per D9 and `isHotkeyKey` per D8.** _Rationale:
this is the load-bearing semantic change; doing it first isolates all case
semantics in one reviewed file. All existing consumers (loader duplicate/
reserved/item-child checks, theme key dedupe, config navigation checks,
`bindFlexible`'s toggle skip) inherit the new identity automatically because
they already call `keyIdentity`._

**Task 2.3 — Tests:** `w`/`W` coexist; duplicates fail per exact case;
`Escape`/`escape` still collide; `#01`/`#1` still collide; printable nav-key
configs reserve only their exact case; generated Themes and Configuration menus
remain valid. _Rationale: OP "Loader and validation" matrix, plus F7's
coverage._

### Phase 3 — Loader precompute (`loader.lua`)

**Task 3.1 — Build `menu.characterRows` in `assembleMenus`:** for each non-
divider, non-footer row where `isCharacterKey(row.key)`, map
`characterRows[row.key] = row`; `assert` on overwrite. _Rationale: O(1)
runtime lookup (F10's premise); uniqueness was already proven during
validation, so a silent overwrite would conceal a validation hole — assert is
the correct failure mode._

**Task 3.2 — Tests:** menu shape assertions for `characterRows` presence and
footer exclusion (D7).

### Phase 4 — Runtime session ownership (`runtime.lua`)

**Task 4.1 — Create the tap and precompute invariants in `Runtime:start()`:**
the keyDown tap, `normalize(config.hotkey.modifiers)`, its
`{cmd, alt, ctrl}` intersection, and `resolvedGlobalKeyCode`. Include tap
construction failure in the existing `xpcall` rollback path. _Rationale: D10,
F10; one native object, zero per-event arithmetic, and the existing partial-
start rollback already handles every other owned object here._

**Task 4.2 — Add `beginSession()` / `endSession()`.** `beginSession()`:
Secure Input precheck (`hs.eventtap.isSecureInputEnabled()`), tap `:start()`,
verify `isEnabled()`; on any failure show one concise `hs.alert` diagnostic and
leave nothing behind (no modal, HUD, timer, or enabled tap; no silent
case-insensitive fallback). `endSession()`: idempotent `tap:stop()`, then exit
the active modal if any (which runs the existing `exited` cleanup). Route the
six terminal paths (timeout, global toggle, `exit` action, `close = true`,
successful scratchpad handoff, `Runtime:stop()`) through `endSession()`.
`openMenu` transitions remain plain exit+enter. _Rationale: OP §6 adopted
unchanged — session-level ownership is strictly better than flag-guarded
`exited` interception because there is no hidden state to reason about. The
`activeMenu == nil` transition gap needs no handling beyond the callback's
first guard (OP §6's final note)._

**Task 4.3 — Implement the tap callback** exactly as the reference procedure
below. _Rationale: the procedure is the compiled form of D1-D6; implementing
anything else is how F1-F6 get reintroduced._

```lua
-- Precomputed at Runtime:start() (F10):
--   configMask        = normalize(config.hotkey.modifiers)            over {cmd, shift, ctrl, alt}
--   configCmdAltCtrl  = configMask ∩ {cmd, alt, ctrl}
--   globalKeycode     = resolved from config.hotkey.key
local function onKeyDown(self, event)
    if not self.activeMenu then return end                       -- transition gap: pass through

    local eventMods = mask(event:getFlags(), ALL_FOUR)           -- {cmd, shift, ctrl, alt}; fn masked (D3)
    local cmdState = mask(event:getFlags(), CMD_ALT_CTRL)

    if cmdState ~= EMPTY and cmdState ~= configCmdAltCtrl then return end   -- D4
    if event:getKeyCode() == globalKeycode
        and includesAll(eventMods, configMask) then return end              -- D5 toggle parity

    local ch = event:getCharacters(true)                         -- layout + shift (+caps iff A2) (D1)
    if ch == nil or #ch ~= 1 or ch < "\x21" or ch > "\x7E" then return end
    -- D1/D2: no inversion unless spike proves caps is stripped; then ASCII letters only, once.

    local row = self.activeMenu.characterRows[ch]
    if not row then return end

    if event:getProperty(props.keyboardEventAutorepeat) ~= 0 then
        return true                                              -- matched repeat: consume, no dispatch (D6)
    end

    self:runAction(self.activeMenu, row)
    return true                                                  -- suppress the underlying app exactly once
end
```

**Task 4.4 — Stop binding character rows in modals:** in `registerMenu`,
non-footer rows with `isCharacterKey(row.key)` get no modal binding; footer
rows stay `bindBare`; anything else stays `bindFlexible`; arrows/activate stay
as-is. _Rationale: mutually exclusive input ownership (OP §2/§3, risk "Double
dispatch") plus D7's footer parity._

**Task 4.5 — Tests (mock-level):** the full Caps × Shift × {bare, chord}
dispatch matrix using Task 1.1's helper; disallowed modifiers neither dispatch
nor consume; unmapped characters pass through; repeat of a matched character is
consumed once, not dispatched (D6); toggle-skip sub-cases from F5's table; tap
starts once per session, survives N menu transitions, stops on every terminal
path; failed scratchpad open keeps the tap; `Runtime:stop()` and rollback leave
nothing; repeated sessions reuse one tap object (count `hs.eventtap.new`
calls); Secure Input failure path leaves zero allocated state. _Rationale: OP's
acceptance matrix compiled into assertions, extended with F3/F6/D6/D10 rows._

### Phase 5 — Menu data and documentation

**Task 5.1 — Uppercase the 27 application-row keys** in the nine named menu
files; navigation/internal-action keys unchanged; do **not** add the root `W`
row (product input still pending per OP). _Rationale: OP §8 and product
decision 7 — convention lives in reviewable data, never in runtime inference.
Update the harness's expected menu shapes in the same step so the suite proves
the migration._

**Task 5.2 — Documentation:** `Spoons/Gearbox/README.md` (Controls: resulting-
character semantics, the Caps/Shift table, Secure Input limitation and the no-
fallback failure mode), `Spoons/Gearbox/menus/README.md` (key schema: uppercase
= application rows, lowercase = navigation, stated as convention not
enforcement; note that footer/navigation keys remain named-modal and that
single-character reserved keys reserve only their exact case),
`tests/README.md` (character-input and event-tap lifecycle coverage row, plus
the spike-matrix comment pointer). _Rationale: OP's documentation list adopted;
D7/D4's behavioral notes must land where a future menu author will read them._

### Phase 6 — Verification

**Task 6.1 — Automated:**

```sh
lua tests/gearbox.lua "$(pwd)"
lua tests/retroui.lua "$(pwd)"
lua tests/retroui-package.lua "$(pwd)"
```

Parse-check every changed Lua file with the available Lua compiler; run
`git diff --check`; review the full diff specifically hunting dual input paths,
tap leaks, hidden `kind`-based inference, and per-event work that belongs in
precomputation. _Rationale: OP's validation commands adopted; no nix steps —
they are out of scope for this Lua change._

**Task 6.2 — Live Hammerspoon acceptance:** the recorded spike matrix replayed
against the real build (all Caps × Shift × chord combinations dispatch
correctly), navigation across child/parent menus with one tap lifetime,
timeout, scratchpad handoff and failed-open retry, and the Secure Input failure
(focus a password field, attempt to open Gearbox). _Rationale: the mock can
never prove AppKit behavior; the spike established the platform boundary, and
this step confirms the shipped code encodes it._

---

## Acceptance-matrix deltas (add to OP's matrix)

- Character semantics: add D3 parity rows (Fn-held presses behave as today);
  D6 (repeat consumed-not-dispatched); D5 toggle sub-cases from F5's table.
- Session lifecycle: add "repeated sessions reuse exactly one tap object" and
  "beginSession re-verifies `isEnabled()` on the reused tap".
- Loader/validation: add D8/D9 rows (printable punctuation accepted as
  character keys; space excluded), D7 (footer never in `characterRows` even
  with a printable `cancelKey`), and the generated-menus regression rows the OP
  already lists.

## Open product decisions (unchanged from OP)

1. The root-menu `W` row: application and label are still unspecified. Do not
   invent them; everything else in this plan is independent of that row.
2. If A2/A3 results contradict the D1/D2 defaults (e.g. caps lock is stripped
   from cleaned characters _and_ absent from event flags), the fallback is the
   documented poll with single-inversion; the spike matrix comment must record
   whichever combination shipped.

## What the implementing agent must not do

- No inversion code without spike evidence (F1).
- No modal bindings for character-classified rows, and no tap dispatch for
  footer/navigation rows (F7a, double-dispatch risk).
- No per-session tap recreation (D10); no per-event set arithmetic (F10).
- No silent case-insensitive fallback when Secure Input blocks capture (OP §7,
  adopted).
- No `kind`- or action-type-based key inference, no new config options, no
  background watchers, no generic input framework (OP decisions 7-9 and
  Non-goals, adopted).
- No nix-related steps or references in this change.
