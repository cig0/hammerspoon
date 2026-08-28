--- Generated Gearbox Configuration menu definitions.
--
-- Passive menu definitions consumed by `loader.lua`; preference behavior
-- remains in `preferences.lua`.
local ConfigurationMenu = {}

--- Return the passive Gearbox Configuration menu graph.
---@return table
function ConfigurationMenu.definitions()
  return {
    {
      id = "configuration",
      title = "Gearbox Configuration",
      emoji = "⚙️",
      parent = "leader",
      legend = "See Spoon documentation to customize the menu shortcut",
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
