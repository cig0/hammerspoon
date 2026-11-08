--- Generated Gearbox Configuration menu definitions.
--
-- Passive menu definitions consumed by `loader.lua`; preference behavior
-- remains in `preferences.lua`.
local ConfigurationMenu = {}

--- Return the passive Gearbox Configuration menu graph.
---@return table
function ConfigurationMenu.definitions()
  -- Use the number row from left to right for the eleven opacity presets.
  local opacityRows = {}
  local keys = "1234567890-"
  for percent = 100, 50, -5 do
    local index = #opacityRows + 1
    opacityRows[index] = {
      key = keys:sub(index, index),
      label = percent .. "%",
      kind = "action",
      action = { type = "configure", operation = "setBackgroundOpacity", value = percent }
    }
  end

  local fontRows = {}
  for size = 12, 18 do
    fontRows[#fontRows + 1] = {
      key = tostring(size - 11),
      label = size .. " pt",
      kind = "action",
      action = { type = "configure", operation = "setFontSize", value = size }
    }
  end

  local timeoutRows = {}
  for index, seconds in ipairs({ 5, 10, 15, 20, 30, 60 }) do
    timeoutRows[index] = {
      key = tostring(index),
      label = seconds .. " seconds",
      kind = "action",
      action = { type = "configure", operation = "setMenuTimeout", value = seconds }
    }
  end

  return {
    {
      id = "font-size",
      title = "Font Size",
      parent = "configuration",
      entry = { key = "F", label = "Font Size" },
      items = fontRows
    },
    {
      id = "menu-transparency",
      title = "Transparency",
      legend = "Menu background opacity",
      parent = "themes",
      entry = { key = "P", label = "Transparency", order = 300 },
      items = opacityRows
    },
    {
      id = "configuration",
      title = "Gearbox Configuration",
      emoji = "⚙️",
      parent = "leader",
      legend = "Choices are saved automatically in the Hammerspoon preferences file:\n" ..
          "~/Library/Preferences/" .. hs.settings.bundleID .. ".plist",
      entry = {
        key = "G",
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
          label = "Save Versioned Profile",
          kind = "action",
          action = { type = "configure", operation = "saveProfile" }
        },
        {
          label = "Reload Versioned Profile",
          kind = "action",
          action = { type = "configure", operation = "reloadProfile" }
        },
        {
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
      entry = { key = "M", label = "Menu Position" },
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
      id = "menu-timeout",
      title = "Menu Timeout",
      parent = "configuration",
      entry = { key = "O", label = "Menu Timeout" },
      items = timeoutRows
    },
    {
      id = "scratchpad-settings",
      title = "Scratchpad",
      parent = "configuration",
      entry = { key = "S", label = "Scratchpad" },
      items = {
        {
          label = "Persist Content",
          kind = "action",
          action = {
            type = "configure",
            operation = "togglePersistence"
          }
        },
        {
          label = "Hammerspoon Settings",
          kind = "action",
          action = {
            type = "configure",
            operation = "useHammerspoonStorage"
          }
        },
        {
          label = "External File…",
          kind = "action",
          action = {
            type = "configure",
            operation = "chooseStorageFolder"
          }
        },
        {
          label = "Filename: scratchpad.txt",
          kind = "action",
          action = { type = "configure", operation = "setFilename" }
        },
        { divider = true },
        { header = "Size" },
        {
          label = "Width",
          kind = "action",
          action = { type = "configure", operation = "setWidth" }
        },
        {
          label = "Height",
          kind = "action",
          action = { type = "configure", operation = "setHeight" }
        }
      }
    }
  }
end

return ConfigurationMenu
