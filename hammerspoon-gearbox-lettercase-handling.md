# Gearbox letter-case input handling plan

## Status and purpose

This is an implementation plan, not an implementation. It is intentionally
self-contained so a later session with no conversation history can understand,
review, and implement the feature without reconstructing the design.

The repository was inspected while drafting this document at commit `9ac9ec4`
on `main`, with a clean primary worktree. Those facts are observational and may
be stale later; verify the checkout and all repository guidance before making
changes.

## Goal

Allow Gearbox menus to distinguish activation characters by their resulting
letter case. For example, a single menu may contain both:

- `w` to navigate to the Web Browsers menu; and
- `W` to launch an application.

The distinction is based on the character produced by the keyboard event, not
on a hard-coded equation of uppercase with `Shift`.

Expected behavior for an ASCII letter:

| Caps Lock | Physical input | Activation character |
| --- | --- | --- |
| off | `w` | `w` |
| off | `Shift+w` | `W` |
| on | `w` | `W` |
| on | `Shift+w` | `w` |

This must remain true when the user holds the configured Gearbox activation
modifiers, provided that modifier combination is one Gearbox already accepts.

## Agreed product decisions

1. Use the resulting character as the semantic input.
2. Use an `hs.eventtap` keyboard tap because `hs.hotkey.modal` identifies a
   physical key plus modifiers and does not directly express this character
   contract.
3. Scope the event tap to an active Gearbox menu session:
   - start it when Gearbox opens;
   - keep it running while navigating between Gearbox menus;
   - stop it when Gearbox closes, times out, stops, or hands control to the
     Scratchpad.
4. Do **not** stop and restart the tap on menu-to-menu transitions. A transition
   changes only the active menu lookup.
5. Printable activation characters belong to the event tap. Named control keys
   such as Escape, Return, Up, and Down remain ordinary modal bindings.
6. Adopt a documented menu-data convention:
   - uppercase letters are used for application-launch rows;
   - lowercase letters are used for menu-navigation rows.
7. Keep that rule a convention rather than inferred behavior. Definitions must
   explicitly contain `key = "W"` or `key = "w"`; runtime code must not rewrite
   keys based on `kind` or action type.
8. Keep action execution and HUD behavior unchanged unless the input work
   exposes a concrete defect.
9. Add no background watcher, polling loop, or timer. When no Gearbox menu is
   active, no keyboard event processing may occur.

## One unresolved product decision

The application, label, and placement for the proposed root-menu `W` launcher
have not been specified. Do not invent them. Before adding that row, obtain the
exact application name and displayed label from the user.

The underlying case-sensitive input support and migration of existing
application keys can otherwise be implemented independently.

## Current architecture and constraints

### Menu data

`Spoons/Gearbox/menus/*.lua` contains passive menu definitions. Parent menu
entries and item rows currently use lowercase key strings. Application rows use
`kind = "application"` with `action.type = "launchApp"`.

At drafting time there are 27 application rows across:

- `agenda.lua`
- `ai.lua`
- `comms.lua`
- `developer.lua`
- `leader.lua`
- `macos.lua`
- `omni.lua`
- `photo-and-video.lua`
- `web-browsers.lua`

The Web Browsers child entry is currently `key = "w"`. Existing application
rows should be migrated to explicit uppercase letters as part of adopting the
convention. Parent/child navigation entries remain lowercase.

Internal actions such as Scratchpad, theme selection, configuration, power
controls, and Finder paths are outside the application/menu convention. Leave
their current case unchanged unless a same-menu collision requires a deliberate
choice.

### Validation

`Spoons/Gearbox/validation.lua` currently provides:

- `isHotkeyKey(key)`, which validates through `hs.keycodes.map[key:lower()]`;
- `keyIdentity(key)`, which lowercases normal key names and canonicalizes raw
  `#<keycode>` strings.

The current `keyIdentity()` deliberately makes `w` and `W` identical. The
loader therefore rejects them as duplicates.

### Loader

`Spoons/Gearbox/loader.lua`:

- discovers and validates the passive menu graph;
- rejects duplicate and reserved keys;
- assembles item, child-menu, divider, and footer rows;
- creates one `hs.hotkey.modal` per menu.

It is the appropriate place to precompute a case-sensitive character-to-row
lookup for each assembled menu. Runtime input should not scan every row on each
key press.

### Runtime

`Spoons/Gearbox/runtime.lua` currently:

- binds every non-divider row through `hs.hotkey.modal`;
- binds a row both bare and with the configured Gearbox modifiers through
  `bindFlexible()`;
- owns `activeMenu`, menu transitions, timeout, HUD, global hotkey, Scratchpad,
  startup rollback, and shutdown cleanup;
- implements a menu transition by exiting the current modal and immediately
  entering the target modal.

The event tap belongs to `Runtime`, because Runtime already owns both the active
menu and the complete session lifecycle. Avoid adding a new production module
unless implementation makes Runtime materially less readable after focused
helpers are extracted.

### Scratchpad

Opening Scratchpad successfully exits the active menu; a failed first open
leaves the menu active for retry. Preserve that behavior:

- successful Scratchpad handoff stops the event tap;
- failed Scratchpad creation leaves the event tap running with the same menu;
- the event tap is never active merely because the Scratchpad WebView exists.

### HUD

`Spoons/Gearbox/hud.lua` already displays `row.displayKey`, a named-key display
alias, or `row.key`. An explicit uppercase `row.key` should therefore render as
uppercase without HUD-specific casing logic.

## Proposed design

### 1. Classify activation keys centrally

Add a small validation helper that identifies keys owned by character input.
Keep its contract narrow and documented.

Recommended initial boundary:

- a single printable ASCII character is a character activation key;
- raw keycodes and named keys remain modal keys;
- ASCII letter identity preserves case;
- non-letter printable identity remains exact;
- named-key identity remains case-insensitive;
- raw `#<keycode>` identity remains numerically canonical.

This permits `w` and `W` in the same menu while continuing to treat `Escape`
and `escape` as the same named key.

Apply the same identity consistently to:

- duplicate item detection;
- item-versus-child collision detection;
- reserved navigation keys;
- global-toggle conflict checks;
- generated supplemental menus.

Do not make all strings case-sensitive: that would accidentally distinguish
case variants of named Hammerspoon keys.

### 2. Precompute per-menu character lookups

During loader assembly, attach a lookup such as `menu.characterRows`:

```lua
menu.characterRows = {
  w = <Web Browsers row>,
  W = <application row>,
}
```

Only non-divider rows classified as character keys enter this table. The loader
has already validated uniqueness, so construction should assert rather than
silently overwrite.

Named keys must continue through modal registration. Character rows must not
also be registered as modal hotkeys, or one physical event could dispatch twice.

### 3. Add one session-scoped key-down event tap

Runtime should own one `hs.eventtap` subscribed only to
`hs.eventtap.event.types.keyDown`.

The callback should:

1. Return without suppressing the event when no Gearbox menu is active.
2. Reject modifier combinations Gearbox did not previously accept.
3. Derive one normalized activation character.
4. Look up that exact character in `activeMenu.characterRows`.
5. Return without suppression when no row matches.
6. Dispatch a matching row through the existing `runAction()` path.
7. Return `true` only for a matched event so the underlying application does
   not also receive it.

Ignore key-repeat events unless a live comparison proves the current modal
behavior intentionally repeats action activation. Arrow-key repeat remains
owned by the existing modal navigation bindings.

### 4. Derive the character without losing Caps Lock semantics

Before implementation, perform the native spike described below. The expected
algorithm is:

1. Use `event:getCharacters(true)` to obtain a keyboard-layout-aware character
   while ignoring Command, Option, and Control but preserving Shift.
2. Read Caps Lock through `hs.eventtap.checkKeyboardModifiers().capslock`.
3. For ASCII letters only, invert the result's case when Caps Lock is active.
4. Accept only a single resulting character.

This expectation follows the documented `getCharacters(clean)` behavior and
AppKit's `charactersIgnoringModifiers` contract, but the actual Hammerspoon and
macOS behavior must be verified before encoding the inversion. Do not apply a
second case inversion if the live event already contains Caps Lock's effect.

Authoritative references:

- <https://www.hammerspoon.org/docs/hs.eventtap.html>
- <https://www.hammerspoon.org/docs/hs.eventtap.event.html#getCharacters>
- <https://developer.apple.com/documentation/appkit/nsevent/charactersignoringmodifiers>

### 5. Preserve existing modifier ergonomics

Current non-footer rows accept either:

- no configured modifiers; or
- exactly the configured Gearbox global modifiers.

Shift and Caps Lock determine character case and should not invalidate either
accepted form. Do not broaden activation so arbitrary Command, Option, Control,
or Fn combinations trigger menu rows.

Normalize the event flags by separating:

- case-related state: Shift and Caps Lock; from
- command state: Command, Option, Control, and Fn.

The command-state set must be either empty or exactly equal to
`config.hotkey.modifiers`. Preserve the existing rule that the full global
toggle chord closes Gearbox instead of triggering a same-key row.

### 6. Separate Gearbox session lifecycle from modal lifecycle

Do not start or stop the tap in every `menu.modal.entered`/`exited` callback.
Those callbacks run during ordinary menu transitions.

Introduce explicit, small Runtime operations for:

- beginning a Gearbox session and entering the root menu;
- switching from one menu to another while retaining the tap;
- ending the session and stopping the tap.

Route every terminal path through the same end-session operation:

- root Exit;
- global Gearbox hotkey while a menu is visible;
- positive timeout expiration;
- an action returning `{ close = true }`;
- successful Scratchpad handoff;
- `Runtime:stop()`;
- startup or replacement rollback after the tap exists.

Menu transitions, Back navigation, theme/configuration refreshes, selection
movement, and failed Scratchpad display are non-terminal and retain the tap.

The transition between two modals is synchronous. During its brief
`activeMenu == nil` interval, the event callback must simply pass input through;
do not add a timer or transition queue for an unobservable gap.

### 7. Handle Secure Input visibly

macOS Secure Input can prevent Hammerspoon from receiving keyboard events.
Check `hs.eventtap.isSecureInputEnabled()` when beginning a Gearbox session and
verify that `inputTap:isEnabled()` succeeds after `start()`.

If character input cannot be captured:

- do not open a partially functional Gearbox menu;
- leave no enabled tap, modal, timer, or HUD behind;
- show one concise diagnostic explaining that Secure Input blocks Gearbox
  character activation;
- do not silently fall back to case-insensitive modal bindings.

No continuous Secure Input watcher is warranted.

### 8. Apply the key convention explicitly in menu data

Change existing application item keys to uppercase in the nine menu files
listed above. Keep child-menu `entry.key` values lowercase.

Do not make the loader enforce `kind == "application"` implies uppercase or
`openMenu` implies lowercase. The convention belongs in documentation and
reviewable menu data, not hidden runtime policy.

Before changing keys, inspect each menu for the now-case-sensitive collision
surface. A lowercase internal action and uppercase application may coexist in
one menu by design.

Do not add the proposed root `W` application row until its target and label are
explicitly known.

## Native behavior spike required before implementation

Mocks cannot establish how the installed Hammerspoon/macOS combination reports
characters. Run a temporary, non-persistent diagnostic in the Hammerspoon
console or an isolated local snippet; do not commit the diagnostic.

Capture for `w` under the active keyboard layout:

| Caps Lock | Shift | Gearbox modifiers | Inspect |
| --- | --- | --- | --- |
| off | off | off | `getCharacters(false/true)`, flags |
| off | on | off | same |
| on | off | off | same |
| on | on | off | same |
| off | off/on | on | same |
| on | off/on | on | same |

Also verify:

- a modal/event tap receives the expected events while Caps Lock is active;
- `start()`, `stop()`, and `isEnabled()` behave reliably across repeated menu
  sessions;
- matched events can be suppressed without double-dispatch;
- Secure Input produces the documented inability to capture, if a safe local
  reproduction is available.

Record the observed character matrix in tests or adjacent documentation so a
later refactor does not rely on recollection.

## Expected files in the later implementation

Production:

- `Spoons/Gearbox/validation.lua`
  - character-key classification and case-aware identity.
- `Spoons/Gearbox/loader.lua`
  - case-aware collision handling and precomputed character-row maps.
- `Spoons/Gearbox/runtime.lua`
  - event tap ownership, input normalization, and session lifecycle.
- `Spoons/Gearbox/menus/{agenda,ai,comms,developer,leader,macos,omni,
  photo-and-video,web-browsers}.lua`
  - explicit uppercase keys for existing application rows.

Documentation:

- `Spoons/Gearbox/README.md`
  - controls, letter-case semantics, Caps Lock behavior, lifecycle, and Secure
    Input limitation.
- `Spoons/Gearbox/menus/README.md`
  - exact key schema and uppercase/lowercase convention.
- `tests/README.md`
  - character-input and event-tap lifecycle coverage.

Tests:

- `tests/gearbox.lua`
  - extend the Hammerspoon double and replace direct printable modal invocations
    with character-event helpers.

Files not expected to change without a discovered reason:

- `Spoons/Gearbox/actions.lua`
- `Spoons/Gearbox/hud.lua`
- `Spoons/Gearbox/scratchpad.lua`
- `Spoons/Gearbox/preferences.lua`
- `Spoons/Gearbox/config.lua`

Avoid creating a generic input framework or new configuration option. This is a
fixed correctness behavior for declarative menu keys.

## Implementation sequence

1. Re-read this plan and inspect current repository guidance and Git state.
2. Confirm explicit authorization to implement; this document alone does not
   authorize later code changes.
3. Use a dedicated task worktree if required by the current repository
   workflow. Do not commit, push, merge, or transfer without separate authority.
4. Run the native behavior spike and record conclusions.
5. Add focused character-key helpers and case-aware identities to validation.
6. Update loader validation and assembly; precompute character-row maps.
7. Add the event-tap double and focused loader/runtime tests before changing
   runtime binding behavior.
8. Implement session-scoped event-tap ownership and central terminal cleanup.
9. Stop registering character rows as modal hotkeys; retain named navigation
   bindings.
10. Convert existing application keys to uppercase and update expected menu
    shapes.
11. Update adjacent documentation.
12. Review the entire diff for duplicated input paths, lifecycle leaks, hidden
    inference, and unnecessary abstractions. Fix all findings.
13. Run the full validation matrix and perform a live Hammerspoon acceptance
    check.

## Regression and acceptance matrix

### Loader and validation

- A menu containing both `w` and `W` loads successfully.
- Duplicate `w` rows fail; duplicate `W` rows fail.
- `Escape` and `escape` remain one named-key identity.
- Raw keycode aliases such as `#01` and `#1` remain one identity.
- Case-aware item/child collisions are handled consistently.
- Reserved single-character navigation keys reserve only the matching case;
  named navigation keys remain case-insensitive.
- Generated Themes and Configuration menus remain valid.

### Character semantics

- Caps off: `w` dispatches `w`; `Shift+w` dispatches `W`.
- Caps on: `w` dispatches `W`; `Shift+w` dispatches `w`.
- The same matrix works with exactly the configured Gearbox modifiers held.
- Disallowed modifier combinations neither dispatch nor suppress the event.
- Unmapped characters pass through without action.
- A matched character dispatches exactly once and is suppressed.
- Case is derived from the event; it is not inferred from row action type.

### Session lifecycle

- Opening Gearbox starts the tap once.
- Moving through any number of child/parent menus does not stop, restart, or
  replace the tap.
- The active character lookup follows the current menu.
- Refresh-only actions retain the tap.
- Root Exit stops the tap.
- The global Gearbox hotkey closes the menu and stops the tap.
- Timeout stops the tap.
- Application launch and other close-result actions stop the tap.
- Successful Scratchpad handoff stops the tap.
- Failed Scratchpad display retains the menu and tap for retry.
- Hiding/showing an existing Scratchpad never starts the tap.
- `Runtime:stop()` and failed startup/replacement leave no enabled tap.
- Repeated Gearbox sessions reuse or recreate the tap according to the chosen
  simple ownership model without accumulating native objects.

### Navigation and existing behavior

- Escape, Return, Up, and Down continue to use modal bindings.
- Arrow repeat, selection, timeout reset, HUD checks, and Back behavior remain
  unchanged.
- All application rows display uppercase activation letters.
- All child-menu entries display lowercase activation letters.
- Theme, configuration, caffeinate, Finder-path, and Scratchpad actions retain
  their intended behavior.
- Global hotkey replacement and partial-start rollback remain failure-safe.

### Secure Input

- Secure Input prevents opening a partially usable menu.
- The failure is visible and concise.
- No tap, modal, HUD, or timeout remains active after failure.
- No silent case-insensitive fallback is installed.

## Test harness changes

Extend the mocked `hs` boundary in `tests/gearbox.lua` with:

- `hs.eventtap.new()` returning a tap double with `start`, `stop`, and
  `isEnabled` state;
- `hs.eventtap.event.types.keyDown`;
- `hs.eventtap.event.properties.keyboardEventAutorepeat`, if repeat filtering
  is implemented;
- `hs.eventtap.checkKeyboardModifiers()` with controllable Caps Lock state;
- `hs.eventtap.isSecureInputEnabled()` with controllable failure state;
- key-event doubles for `getCharacters`, `getFlags`, and repeat properties.

Provide one test helper that sends a character event with explicit Shift, Caps
Lock, and command-state flags. Replace existing calls such as
`menu.modal.bindings.m()` for printable keys with that helper. Keep direct modal
invocation for named keys such as Escape and Return.

Do not make the mock reproduce all of AppKit. Its job is to validate Gearbox's
decision logic after the native spike establishes the platform boundary.

## Validation commands

From the repository root, run at minimum:

```sh
lua tests/gearbox.lua "$(pwd)"
lua tests/retroui.lua "$(pwd)"
lua tests/retroui-package.lua "$(pwd)"
```

Parse every changed Lua file with the available Lua compiler, run
`git diff --check`, and review all staged and unstaged paths independently.

The final acceptance pass must also run in Hammerspoon itself because the
command-line mock cannot prove native event-character, Caps Lock, Secure Input,
or event suppression behavior.

## Risk review

### Double dispatch

Risk: a character row remains bound through both `hs.hotkey.modal` and the event
tap.

Protection: make input ownership mutually exclusive and assert binding counts
in tests.

### Event-tap leak

Risk: a terminal path closes the HUD but leaves keyboard interception enabled.

Protection: centralize end-session cleanup and cover every terminal path.

### Accidental stop during navigation

Risk: `menu.modal.exited` stops the tap while switching menus.

Protection: session lifecycle, not individual modal callbacks, owns the tap.

### Incorrect Caps Lock inversion

Risk: platform character conversion already includes Caps Lock and Gearbox
inverts it twice.

Protection: complete the live matrix before finalizing normalization.

### Modifier regression

Risk: Option/Command change the produced character, or arbitrary modifiers
begin triggering actions.

Protection: use cleaned characters and explicitly validate command-state flags
against the two combinations Gearbox already accepts.

### Secure Input degradation

Risk: Gearbox opens but printable actions do nothing.

Protection: verify tap availability before displaying the menu and fail visibly.

### Scope growth

Risk: the change expands into a general Unicode shortcut engine, input-method
framework, configurable case policy, or action-type inference.

Protection: retain the initial single-printable-character boundary and explicit
menu data.

## Non-goals

- Interpreting uppercase as permanently equivalent to `Shift+letter`.
- Inferring key case from `kind` or action type.
- Supporting arbitrary multi-character shortcuts or composed/dead-key input.
- Adding per-user configuration for the casing convention.
- Running the event tap while Gearbox menus are closed.
- Running the event tap while Scratchpad owns input.
- Reworking action execution, HUD layout, menu ordering, preferences, or
  Scratchpad editing.
- Adding background monitoring for Caps Lock, keyboard layout, or Secure Input.

## Definition of done

The work is complete only when:

1. `w` and `W` coexist in one menu and dispatch by resulting character across
   all four Shift/Caps Lock combinations.
2. The event tap remains enabled across menu navigation and stops on every true
   Gearbox-session termination.
3. Scratchpad never shares active text input with the event tap.
4. Existing application rows explicitly use uppercase keys and child-menu rows
   explicitly use lowercase keys.
5. No hidden action-type inference or fallback behavior was introduced.
6. Secure Input failure is visible and leaves no partial runtime state.
7. Mocked suites, Lua parsing, diff checks, and the native Hammerspoon matrix all
   pass.
8. The complete diff has been reviewed for leaks, double bindings, ambiguity,
   unnecessary abstraction, and unrelated changes, with all findings fixed.
