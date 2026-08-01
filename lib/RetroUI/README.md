# RetroUI

RetroUI is a standalone, canvas-backed Hammerspoon toolkit for compact
retro-styled dialogs. It is independent of Gearbox and can be consumed by any
Hammerspoon code that can require `lib.RetroUI`. Gearbox ships a byte-identical
private copy and loads it under `Spoons.Gearbox.lib.RetroUI`, allowing bundled
versions to coexist in Hammerspoon's shared Lua process.

The canonical `lib/RetroUI/package.json` is the version authority. Gearbox
ships a byte-identical copy beside its private namespace, so an installed Spoon
also records the exact bundled version. The interactive API is version `0.2.0`;
consumers should pin or record that version when they bundle the library.

## Included primitives

- `Frame.render(spec)` renders a pure text-frame model with `single` or
  `double` borders, left/center/right title alignment, and independent top,
  right, bottom, and left padding.
- `Theme.resolve(id, overrides)` supplies the bundled `danger`, `borland`, and
  `monochrome` themes and validates semantic overrides.
- `ButtonGroup.new(buttons)` owns focus, mnemonics, default activation, Tab
  navigation, and pressed state.
- `Dialog.show(spec)` binds the model to `hs.canvas`, keyboard input, mouse
  input, and an optional dismissal timer.

The dialog canvas is non-activating. Keyboard input belongs to its temporary
modal; mouse input is handled through canvas tracking rectangles. A button
face shifts down-right while it is pressed, covering its fixed shadow.

Theme precedence is structural defaults, named preset, then `themeOverrides`;
the dialog's `frameStyle`, `titleAlignment`, and `padding` can make local layout
choices without changing the shared theme. Themes contain visual data only;
dialog specs own buttons, timeout, and dismissal behavior.

## Example

```lua
local RetroUI = require("lib.RetroUI")

local dialog = RetroUI.Dialog.show({
  theme = "borland",
  title = "Build complete",
  titleAlignment = "center",
  frameStyle = "double",
  padding = {top = 1, right = 3, bottom = 1, left = 3},
  content = {{text = "No errors reported.", role = "body"}},
  footer = {
    text = "This dialog closes in 30 seconds.",
    role = "notice",
    buttonId = "accept",
  },
  buttons = {{
    id = "accept",
    label = "Accept",
    hotkey = "a",
    default = true,
    enabled = true,
  }},
  dismissAfter = 30,
})
```

`content` roles select semantic dialog colors: `title`, `notice`, `hotkey`,
and the body color used for every other role. A theme can independently set
those colors, its fixed-pitch font and text weights, frame defaults, outer
padding, button padding and spacing, shadow and press offsets, and all button
state colors. Per-dialog `frameStyle`, `titleAlignment`, and `padding` override
the corresponding theme defaults.

An optional `footer` places semantic text and one named button on the same row
below the frame. Its `buttonId` must identify an entry in `buttons`; that action
keeps the normal mouse, mnemonic, Return, focus, pressed-state, and dismissal
behavior. Any remaining buttons keep their ordinary row beneath the footer.

The optional `dismissOnEscape` and `dismissOnBackgroundClick` flags default to
`false`. `onDismiss(reason, buttonId)` receives `button`, `timeout`, or
`programmatic`; `buttonId` is present for button activation. Call `delete()`
for idempotent programmatic cleanup.

The public API intentionally accepts semantic colors and layout data rather
than Gearbox configuration. It supports ASCII and the included single-cell box
glyphs; emoji, combining marks, and wide characters are not supported.
Mouse buttons support hover, left-button press/release, and the same delayed
pressed-face effect as keyboard activation. Optional background-click
dismissal requires a complete left-button click on the canvas. Arbitrary
window dragging is not part of this version.
