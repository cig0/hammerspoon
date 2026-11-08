# Gearbox menus

`menus/` is the declarative menu graph. No runtime, no hotkeys — just data.

```text
menus/*.lua → loader.lua → runtime.lua → hud.lua
  discovery + validation → ordering + dividers + footer → dispatch + modal
```

- One file = one menu: `return { id, title, parent?, entry?, items? }`
- Ignored: dotfiles (`.foo.lua`), underscore prefix (`_draft.lua`)
- No load order. Every file joins the same validated graph.

## Shape

```lua
-- menus/acme.lua — copy this
return {
  id = "acme",           -- [a-z0-9_-]+, unique
  title = "ACME",        -- HUD header, required
  emoji = "🧪",           -- optional
  parent = "leader",     -- omit only for root (leader)
  entry = {              -- required if parent exists
    key = "a",           -- one printable ASCII (no space), case-sensitive
    label = "ACME",      -- shown in parent; defaults to title
    section = "groups",  -- default group
    sectionOrder = 100,  -- lower first; 200 = utilities
    order = 10,          -- within section; explicit < implicit
  },
  items = {              -- in file order; your dividers only
    { key = "F", label = "FooBar", kind = "application", action = { type = "launchApp", name = "FooBar" } },
    { divider = true },
    { label = "Dummy action", kind = "action", action = { type = "openPath", path = os.getenv("HOME") .. "/dummy" } }, -- no key = arrow-only
    { key = "x", label = "ACME hidden", requires = "acme", kind = "application", action = { type = "launchApp", name = "ACME" } },
  },
  -- showFooterDivider = false
}
```

## Fields

| Field                                      | Notes                                                                                                                                |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `id`                                       | Stable identity. Rename = break `parent` refs.                                                                                       |
| `title` / `emoji` / `legend`               | HUD header. `legend` = small help text.                                                                                              |
| `parent` / `entry`                         | Where you hang. Root `leader` has neither.                                                                                           |
| `entry.section` / `sectionOrder` / `order` | Sorted placement of sibling menus. Same `section` must share `sectionOrder`.                                                         |
| `items`                                    | Rows. File order. `{ divider = true }` = separator. `{ header = "Title" }` = inline non-navigable label (e.g. `Size` in Scratchpad). |
| `items[].key`                              | Optional. If present: single printable ASCII `0x21..0x7e`. If absent: row is arrow/return only.                                      |
| `items[].requires`                         | Gated by `config.<name>.enable` (e.g. `scratchpad`).                                                                                 |
| `items[].action`                           | Validated by `actions.lua`, run by `runtime.lua`.                                                                                    |
| `showFooterDivider`                        | `true` (default) = divider before Back/Exit.                                                                                         |

## Keys

- One printable ASCII `0x21..0x7e`. `w` ≠ `W` ≠ `1` ≠ `!`. Omit `key` to make a row arrow-only (no letter dispatch, no key cap).
- Dispatch uses the produced character (Shift/Caps Lock matter) — not the physical chord.
- Reserved: `escape` + `config.navigation.*` (`cancelKey`, `activateKey`, `up`/`down` when enabled). A reserved letter blocks both cases.
- No raw keycodes (`#123`) or keypad names (`pad1`) — they alias character rows.

Convention: lowercase for navigation, uppercase for apps. Loader doesn't enforce it, you do. Prefer removing keys over hiding them — hidden activators cause operational confusion.

## Ordering

1. `items` stay as written. You own dividers.
2. Child menus auto-sort inside each `section`: `sectionOrder` → `entry.order` → `label` (case-insensitive) → `id`
3. Loader adds `Back` (submenu) / `Exit` (root) + dividers. Don't write them.

To put a new menu in utilities after macOS Utilities: `entry = { key="z", label="Dummy", section="utilities", sectionOrder=200, order=15 }`

## Recipes

**Add an app row to `menus/acme.lua`:**

```lua
{ key = "B", label = "Baz", kind = "application", action = { type = "launchApp", name = "Baz" } },
```

**Add an arrow-only row:**

```lua
{ label = "Dummy (arrow only)", kind = "action", action = { type = "sleep" } },
```

**Add a submenu `menus/foobar.lua`:**

```lua
return {
  id = "foobar",
  title = "Foobar",
  parent = "leader",
  entry = { key = "b", label = "Foobar" },
  items = {
    { key = "D", label = "Dummy", kind = "application", action = { type = "launchApp", name = "Dummy" } },
  },
}
```

**Reparent under ACME:**

```lua
parent = "acme" -- entry.key must be unique in acme
```

Save, reload Hammerspoon. On Nix edit the repo — `~/.hammerspoon` is overwritten on activation.

## Generated menus

Not in `menus/`. Injected as supplemental definitions (same shape, owned by their modules):

- `theme.lua` → `themes` + `matching-themes` under Gearbox Configuration — arrow-only by design (no keys, ↑↓+return)
- `configuration_menu.lua` via `preferences.lua` → Gearbox Configuration subtree — `configuration` and `scratchpad-settings` are arrow-only; `menu-position`, `menu-timeout`, `font-size`, `menu-transparency` keep letter keys. `scratchpad-settings` uses an inline `{ header = "Size" }` row for the Width/Height group.

Don't recreate them in `menus/`. If you add keys to generated rows, validation enforces them.

## Actions

| type                                   | Effect                                               |
| -------------------------------------- | ---------------------------------------------------- |
| `launchApp`                            | `hs.application.launchOrFocus(name)`                 |
| `openPath`                             | `hs.open(path)`                                      |
| `openMenu`                             | Navigate `{ menu="acme" }` — prefer `parent`/`entry` |
| `openScratchpad`                       | Show scratchpad + dismiss                            |
| `setCaffeinateMode`                    | `display` / `idle` / `normal`                        |
| `setTheme` / `setMatchingTheme`        | Pick palette, refresh HUD                            |
| `configure`                            | `preferences.lua` ops                                |
| `reload` / `sleep` / `exit` / `custom` | `hs.reload`, sleep, exit, callback                   |

## Layout

- Root `leader` width is `config.menu.width` = `620` for 3-col Hyperkey/Caps Lock (`420` for old 2-col). `hud.lua:appendQuickLaunch` and `hud.lua:menuContentTop` both use `ceil(#keys/3)` and `width/3` — keep divisor in sync. Widen via `config.lua:menu.width`.
- Quick Launch `hyperkeys.lua` is a list of tuples `{{key="a", target="ACME"}, {key="f", target={type="openMenu", menu="finder"}}}` — **key is free choice, display is alphabetical by label** (`labels[a]:lower()`), same as `leader` submenus (`sortedSections` by `label`). File order doesn't matter; `loader.lua` sorts. Legacy map `{a="ACME"}` still works but was key-sorted — don't use it.
- Inline headers: `{ header = "Size" }` renders as secondary-color small text (non-navigable, excluded from `runtime.navigableRows`). No `key`/`label`/`kind`/`action` allowed alongside `header`.

## Validation

Fails on `Gearbox.start()` before any modal builds: duplicate `id`/key (only when `key` present), missing `parent`, cycle, bad key, reserved nav key, unknown `kind`/`type`, missing action target. `key=nil` and `header` rows skip key checks — use them for arrow-only rows. `header` must not coexist with `key`/`label`/`kind`/`action`.

## Where to look next

- `../README.md` — install, hotkey, config
- `../themes/README.md` — palette contract (now arrow-only, no per-palette keys)
- `../loader.lua` — discovery / validation / sorting impl
- `../preferences.lua` + `../configuration_menu.lua` — generated config menus (arrow-only items)
- `../theme.lua` — generated themes menus (arrow-only items)
