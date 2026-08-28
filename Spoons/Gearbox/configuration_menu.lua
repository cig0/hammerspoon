--- Generated Gearbox Configuration menu definitions.
--
-- Input: the validated authoritative Gearbox configuration. Output: passive
-- menu definitions consumed by `loader.lua`; preference behavior remains in
-- `preferences.lua`.
local ConfigurationMenu = {}

local modifierSymbols = {
  alt = "⌥",
  cmd = "⌘",
  ctrl = "⌃",
  shift = "⇧"
}

local keyDisplayNames = {
  down = "↓",
  escape = "Esc",
  left = "←",
  ["return"] = "Return",
  right = "→",
  space = "Space",
  tab = "Tab",
  up = "↑"
}

--- Return the configured Gearbox trigger in familiar macOS notation.
local function triggerLegend(hotkey)
  local displayedModifiers = {}

  for _, modifier in ipairs(hotkey.modifiers) do
    table.insert(displayedModifiers, modifierSymbols[modifier] or modifier)
  end

  local displayedKey = keyDisplayNames[hotkey.key] or
      (#hotkey.key == 1 and hotkey.key:upper() or hotkey.key)

  return "Trigger: " .. table.concat(displayedModifiers) .. displayedKey ..
      " · Customizable via Spoon docs"
end

--- Build the configuration menu graph from the active Gearbox trigger.
---@param config table
---@return table
function ConfigurationMenu.definitions(config)
  return {
    {
      id = "configuration",
      title = "Gearbox Configuration",
      emoji = "⚙️",
      parent = "leader",
      legend = triggerLegend(config.hotkey),
      entry = {
        key = "g",
        label = "Gearbox Configuration",
        section = "utilities",
        sectionOrder = 200
      },
      items = {
        {
          key = "h",
          label = "Reload Hammerspoon",
          kind = "action",
          action = { type = "reload" }
        },
        { divider = true },
        {
          key = "p",
          label = "Save Versioned Profile",
          kind = "action",
          action = { type = "configure", operation = "saveProfile" }
        },
        {
          key = "r",
          label = "Reload Versioned Profile",
          kind = "action",
          action = { type = "configure", operation = "reloadProfile" }
        },
        {
          key = "x",
          label = "Reset Local Overrides",
          kind = "action",
          action = { type = "configure", operation = "resetLocal" }
        }
      }
    },
    {
      id = "menu-position",
      title = "Menu Position",
      parent = "configuration",
      entry = { key = "m", label = "Menu Position" },
      items = {
        {
          key = "t",
          label = "Top",
          kind = "action",
          action = {
            type = "configure",
            operation = "setPosition",
            value = "top"
          }
        },
        {
          key = "b",
          label = "Bottom",
          kind = "action",
          action = {
            type = "configure",
            operation = "setPosition",
            value = "bottom"
          }
        }
      }
    },
    {
      id = "scratchpad-settings",
      title = "Scratchpad",
      parent = "configuration",
      entry = { key = "s", label = "Scratchpad" },
      items = {
        {
          key = "p",
          label = "Persist Content",
          kind = "action",
          action = {
            type = "configure",
            operation = "togglePersistence"
          }
        },
        {
          key = "h",
          label = "Hammerspoon Settings",
          kind = "action",
          action = {
            type = "configure",
            operation = "useHammerspoonStorage"
          }
        },
        {
          key = "f",
          label = "External File…",
          kind = "action",
          action = {
            type = "configure",
            operation = "chooseStorageFolder"
          }
        },
        {
          key = "n",
          label = "Filename: scratchpad.txt",
          kind = "action",
          action = { type = "configure", operation = "setFilename" }
        },
        { divider = true },
        {
          key = "w",
          label = "Width",
          kind = "action",
          action = { type = "configure", operation = "setWidth" }
        },
        {
          key = "e",
          label = "Height",
          kind = "action",
          action = { type = "configure", operation = "setHeight" }
        }
      }
    }
  }
end

return ConfigurationMenu
