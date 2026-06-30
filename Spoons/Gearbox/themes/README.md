# Gearbox themes

`themes/` contains passive visual definitions. Every visible `.lua` file is
loaded, validated, and added to the generated Themes menu.

```text
themes/*.lua
  → theme.lua discovery, validation, and overrides
  → light/dark menu groups sorted by label
  → HUD semantic colors
```

## Definition shape

Each theme owns:

| Field | Purpose |
| --- | --- |
| `id` | Stable selection and persistence value |
| `label`, `key` | Themes menu presentation |
| `group` | `light` or `dark` menu section |
| `selectionAlpha` | Highlight transparency |
| `background` | HUD surface |
| `primary` | Title and primary text |
| `secondary` | Supporting text |
| `divider` | Section separators |
| `accent` | Group keys, checks, and selection |
| `accentText` | Text rendered over the accent |

Colors use one complete model: `{ white, alpha }` or
`{ red, green, blue, alpha }`. Partial user overrides may omit `alpha`; the
theme's existing alpha is retained.

## Bundled themes

| Group | Theme | Key |
| --- | --- | --- |
| Light | Catppuccin Latte | `a` |
| Light | Gearbox Light | `l` |
| Light | Gruvbox Light | `g` |
| Dark | Catppuccin Mocha | `c` |
| Dark | Dracula | `r` |
| Dark | Gearbox Dark | `d` |
| Dark | Gruvbox Dark Hard | `h` |
| Dark | Monokai | `m` |
| Dark | Nord | `n` |
| Dark | Tokyo Night | `t` |

## Selection flow

`theme.name = "system"` maps the current macOS appearance to
`theme.system.light` or `theme.system.dark` whenever a menu opens. A fixed
theme ID bypasses that appearance query.

With `theme.persistSelection = true`, menu choices are stored under
`hs.settings["Gearbox.theme.selection"]` and restored after a Hammerspoon reload.
The stored choice is discarded when the configured default changes or the
selected theme no longer exists. The detailed storage and Nix behavior are in
the [Gearbox configuration](../README.md#theme-persistence) section.

## Palette provenance

Bundled third-party presets map upstream palette roles onto Gearbox's semantic
surfaces:

| Preset | Upstream | License |
| --- | --- | --- |
| Gruvbox | [morhetz/gruvbox](https://github.com/morhetz/gruvbox) | [MIT/X11](https://github.com/morhetz/gruvbox#license) |
| Catppuccin | [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin) | [MIT](https://github.com/catppuccin/catppuccin/blob/main/LICENSE) |
| Monokai | [Sublime Text default packages](https://github.com/sublimehq/Packages) | [Upstream license](https://github.com/sublimehq/Packages/blob/master/LICENSE) |
| Nord | [Nord palette](https://www.nordtheme.com/docs/colors-and-palettes) | [MIT](https://github.com/nordtheme/nord/blob/develop/license) |
| Dracula | [dracula/dracula-theme](https://github.com/dracula/dracula-theme) | [MIT](https://github.com/dracula/dracula-theme/blob/main/LICENSE) |
| Tokyo Night | [tokyo-night/tokyo-night-vscode-theme](https://github.com/tokyo-night/tokyo-night-vscode-theme) | [MIT](https://github.com/tokyo-night/tokyo-night-vscode-theme/blob/master/LICENSE.txt) |
