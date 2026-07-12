--- Theme loading, persistence, and dynamic accent handling.
--
-- Discovers themes from disk, applies user overrides, tracks the macOS accent
-- color, persists the user's selection, and exposes the generated theme picker
-- menu.
local Theme = {}
---@class Theme
---@field config table
---@field themes table
---@field configuredDefault string
---@field clearLegacySelectionOnActivation boolean
---@field clearStoredSelectionOnActivation boolean
---@field selectionToPersistOnActivation table|nil
---@field systemAccent table
---@field fonts table
---@field selection string
---@field activeThemeId string|nil
---@field colors table|nil
Theme.__index = Theme

local settingsKey = "Gearbox.theme.selection"
local legacySettingsKey = "Shift7.theme.selection"

local legacyThemeIds = {
  ["shift7-dark"] = "gearbox-dark",
  ["shift7-light"] = "gearbox-light",
}

local accentScript = [[
  ObjC.import("AppKit")

  const color = $.NSColor.controlAccentColor
    .colorUsingColorSpace($.NSColorSpace.sRGBColorSpace)

  JSON.stringify({
    red: Number(color.redComponent),
    green: Number(color.greenComponent),
    blue: Number(color.blueComponent),
    alpha: Number(color.alphaComponent)
  })
]]

local themeGroups = {
  light = true,
  dark = true,
}

local visualFields = {
  selectionAlpha = true,
  background = true,
  primary = true,
  secondary = true,
  divider = true,
  accent = true,
  accentText = true,
}

local colorFields = {
  background = true,
  primary = true,
  secondary = true,
  divider = true,
  accent = true,
  accentText = true,
}

--- Raise a Gearbox-prefixed error at the caller's level.
---@param message string
---@param level? integer
local function fail(message, level)
  error("Gearbox: " .. message, (level or 1) + 1)
end

--- Deep-copy a table. Non-tables pass through unchanged.
---@param value any
---@return any
local function copyTable(value)
  if type(value) ~= "table" then
    return value
  end

  local result = {}

  for key, item in pairs(value) do
    result[key] = copyTable(item)
  end

  return result
end

--- Map legacy Shift7 theme selection records to Gearbox IDs.
---@param stored any
---@return any
local function migrateLegacySelection(stored)
  if type(stored) ~= "table" then
    return stored
  end

  local migrated = copyTable(stored)
  migrated.selection =
      legacyThemeIds[migrated.selection] or migrated.selection

  migrated.configuredDefault =
      legacyThemeIds[migrated.configuredDefault]
      or migrated.configuredDefault

  return migrated
end

--- Classify a color table as "grayscale", "rgb", "mixed", or nil.
---@param value any
---@return "grayscale"|"rgb"|"mixed"|nil
local function colorModel(value)
  if type(value) ~= "table" then
    return nil
  end

  local hasWhite = value.white ~= nil
  local hasRGB =
      value.red ~= nil
      or value.green ~= nil
      or value.blue ~= nil

  if hasWhite and hasRGB then
    return "mixed"
  end

  if hasWhite then
    return "grayscale"
  end

  if hasRGB then
    return "rgb"
  end

  return nil
end

--- Validate that `value` is a number in [0, 1].
---@param value any
---@param name string
local function validateUnit(value, name)
  if type(value) ~= "number" or value < 0 or value > 1 then
    fail(name .. " must be a number from 0 to 1", 2)
  end
end

--- Validate a color table.
---@param color table
---@param name string
---@param requireAlpha boolean
local function validateColor(color, name, requireAlpha)
  if type(color) ~= "table" then
    fail(name .. " must be a color table", 2)
  end

  local model = colorModel(color)

  if model == "mixed" then
    fail(name .. " cannot mix white with RGB components", 2)
  end

  if model ~= "grayscale" and model ~= "rgb" then
    fail(name .. " must define white or red, green, and blue", 2)
  end

  if model == "grayscale" then
    validateUnit(color.white, name .. ".white")
  else
    for _, component in ipairs({ "red", "green", "blue" }) do
      validateUnit(color[component], name .. "." .. component)
    end
  end

  if requireAlpha and color.alpha == nil then
    fail(name .. ".alpha is required", 2)
  end

  if color.alpha ~= nil then
    validateUnit(color.alpha, name .. ".alpha")
  end
end

--- Return true when `key` is a valid Hammerspoon key name.
---@param key string
---@return boolean
local function validHotkeyKey(key)
  if key:match("^#%d+$") then
    return true
  end

  return hs.keycodes.map[key:lower()] ~= nil
end

--- Normalize a key string for duplicate-key detection.
---@param key string
---@return string
local function keyIdentity(key)
  if key:match("^#%d+$") then
    return "#" .. tonumber(key:sub(2))
  end

  return key:lower()
end

--- List non-hidden `.lua` theme files in `directory`.
---@param directory string
---@return table
local function themeFiles(directory)
  local files = {}

  for file in hs.fs.dir(directory) do
    local firstCharacter = file:sub(1, 1)

    if file:match("%.lua$")
        and firstCharacter ~= "."
        and firstCharacter ~= "_" then
      table.insert(files, file)
    end
  end

  table.sort(files)
  return files
end

--- Validate one theme definition returned by a theme module.
---@param definition table
---@param source string
local function validateDefinition(definition, source)
  if type(definition) ~= "table" then
    fail(source .. " must return one theme definition", 2)
  end

  if type(definition.id) ~= "string"
      or not definition.id:match("^[%w_-]+$")
      or definition.id == "system" then
    fail(source .. " has an invalid or reserved theme id", 2)
  end

  if type(definition.label) ~= "string" or definition.label == "" then
    fail(definition.id .. " is missing its label", 2)
  end

  if type(definition.key) ~= "string"
      or definition.key == ""
      or not validHotkeyKey(definition.key) then
    fail(definition.id .. " has an invalid or missing menu key", 2)
  end

  if not themeGroups[definition.group] then
    fail(definition.id .. " group must be light or dark", 2)
  end

  validateUnit(
    definition.selectionAlpha,
    definition.id .. ".selectionAlpha"
  )

  for field in pairs(colorFields) do
    validateColor(
      definition[field],
      definition.id .. "." .. field,
      true
    )
  end
end

--- Load and index all theme modules from disk.
---@param directory string
---@return table
local function loadThemes(directory)
  local themes = {}
  local menuKeys = {
    s = "Follow macOS",
  }
  local files = themeFiles(directory)

  if #files == 0 then
    fail("no theme modules found in " .. directory, 2)
  end

  for _, file in ipairs(files) do
    local path = directory .. "/" .. file
    local chunk, loadError = loadfile(path)

    if not chunk then
      fail(("cannot load %s: %s"):format(path, loadError), 2)
    end

    local ok, definition = pcall(chunk)

    if not ok then
      fail(("theme module %s failed: %s"):format(path, definition), 2)
    end

    validateDefinition(definition, file)

    if themes[definition.id] then
      fail("duplicate theme id: " .. definition.id, 2)
    end

    local key = keyIdentity(definition.key)

    if menuKeys[key] then
      fail(
        ("duplicate theme menu key %s in %s and %s")
        :format(definition.key, menuKeys[key], definition.id),
        2
      )
    end

    definition = copyTable(definition)
    definition._source = file
    themes[definition.id] = definition
    menuKeys[key] = definition.id
  end

  return themes
end

--- Apply user overrides to the loaded theme definitions.
---@param themes table
---@param overrides table
local function applyOverrides(themes, overrides)
  if type(overrides) ~= "table" then
    fail("theme.overrides must be a table", 2)
  end

  for id, override in pairs(overrides) do
    local definition = themes[id]

    if not definition then
      fail("theme override references unknown theme: " .. tostring(id), 2)
    end

    if type(override) ~= "table" then
      fail("theme.overrides." .. id .. " must be a table", 2)
    end

    for field, value in pairs(override) do
      if not visualFields[field] then
        fail(("theme override %s has unknown field: %s"):format(id, field), 2)
      end

      if field == "selectionAlpha" then
        validateUnit(value, "theme.overrides." .. id .. "." .. field)
        definition[field] = value
      else
        validateColor(
          value,
          "theme.overrides." .. id .. "." .. field,
          false
        )

        local color = copyTable(value)
        color.alpha = color.alpha or definition[field].alpha
        definition[field] = color
      end
    end
  end
end

--- Resolve a font table from config and optional default.
---@param config table
---@param defaultFont any
---@param size number
---@param weight "regular"|"bold"
---@return table
local function configuredFont(config, defaultFont, size, weight)
  local font

  if config.font.family then
    font = {
      name = config.font.family,
      size = size,
    }
  elseif type(defaultFont) == "table" then
    font = {
      name = defaultFont.name,
      size = size,
    }
  elseif type(defaultFont) == "string" then
    font = {
      name = defaultFont,
      size = size,
    }
  else
    font = { size = size }
  end

  if weight == "bold" then
    return hs.styledtext.convertFont(font, true)
  end

  return font
end

--- Query the current macOS control accent color via JavaScript for Automation.
---@return table|nil
local function macOSAccentColor()
  local invoked, ok, encodedColor = pcall(
    hs.osascript.javascript,
    accentScript
  )

  if not invoked or not ok or type(encodedColor) ~= "string" then
    return nil
  end

  local decoded, color = pcall(hs.json.decode, encodedColor)

  if not decoded or type(color) ~= "table" then
    return nil
  end

  local valid =
      type(color.red) == "number"
      and type(color.green) == "number"
      and type(color.blue) == "number"
      and type(color.alpha) == "number"

  return valid and color or nil
end

--- Return theme definitions in `group`, sorted by label then id.
---@param themes table
---@param group "light"|"dark"
---@return table
local function sortedThemes(themes, group)
  local result = {}

  for _, definition in pairs(themes) do
    if definition.group == group then
      table.insert(result, definition)
    end
  end

  table.sort(result, function(left, right)
    if left.label ~= right.label then
      return left.label:lower() < right.label:lower()
    end

    return left.id < right.id
  end)

  return result
end

--- Create a new theme manager.
---@param config table
---@param rootDirectory string
---@return Theme
function Theme.new(config, rootDirectory)
  if config.font.family then
    assert(
      hs.styledtext.validFont(config.font.family),
      "Gearbox: invalid font: " .. config.font.family
    )
  end

  local themes = loadThemes(rootDirectory .. "/themes")
  applyOverrides(themes, config.theme.overrides)

  local self = setmetatable({}, Theme)

  self.config = config
  self.themes = themes
  self.configuredDefault = config.theme.name
  self.clearLegacySelectionOnActivation = false
  self.clearStoredSelectionOnActivation = false
  self.selectionToPersistOnActivation = nil

  for style, id in pairs(config.theme.system) do
    if not themes[id] then
      fail(("theme.system.%s references unknown theme: %s"):format(style, id), 2)
    end
  end

  if config.theme.name ~= "system" and not themes[config.theme.name] then
    fail("theme.name references unknown theme: " .. config.theme.name, 2)
  end

  self.systemAccent = config.theme.fallbackAccent

  if config.theme.accentSource == "system" then
    self.systemAccent = macOSAccentColor() or self.systemAccent
  end

  local defaultFont

  if not config.font.family then
    defaultFont = hs.canvas.defaultTextStyle().font
  end

  self.fonts = {
    body = configuredFont(
      config,
      defaultFont,
      config.font.size,
      config.font.bodyWeight
    ),
    group = configuredFont(
      config,
      defaultFont,
      config.font.size,
      config.font.groupWeight
    ),
    title = configuredFont(
      config,
      defaultFont,
      config.font.titleSize,
      config.font.titleWeight
    ),
  }

  self.selection = self:restoredSelection()

  return self
end

--- Return true when `selection` is a known theme or "system".
---@param selection string
---@return boolean
function Theme:isValidSelection(selection)
  return selection == "system" or self.themes[selection] ~= nil
end

--- Restore the persisted theme selection or fall back to the configured default.
---@return string
function Theme:restoredSelection()
  if not self.config.theme.persistSelection then
    self.clearLegacySelectionOnActivation = true
    self.clearStoredSelectionOnActivation = true
    return self.configuredDefault
  end

  local stored = hs.settings.get(settingsKey)
  local legacyStored = hs.settings.get(legacySettingsKey)
  local usingLegacy = stored == nil and legacyStored ~= nil

  if legacyStored ~= nil then
    self.clearLegacySelectionOnActivation = true
  end

  if usingLegacy then
    stored = migrateLegacySelection(legacyStored)
  end

  if type(stored) == "table"
      and stored.configuredDefault == self.configuredDefault
      and self:isValidSelection(stored.selection) then
    if usingLegacy then
      self.selectionToPersistOnActivation = stored
    end

    return stored.selection
  end

  if stored ~= nil then
    self.clearStoredSelectionOnActivation = true
  end

  return self.configuredDefault
end

--- Persist or clear stored selection records during startup.
function Theme:activate()
  if self.clearStoredSelectionOnActivation then
    hs.settings.clear(settingsKey)
    self.clearStoredSelectionOnActivation = false
  elseif self.selectionToPersistOnActivation then
    hs.settings.set(settingsKey, self.selectionToPersistOnActivation)
    self.selectionToPersistOnActivation = nil
  end

  if self.clearLegacySelectionOnActivation then
    hs.settings.clear(legacySettingsKey)
    self.clearLegacySelectionOnActivation = false
  end
end

--- Store the current selection under `hs.settings`.
function Theme:persistSelection()
  if not self.config.theme.persistSelection then
    return
  end

  hs.settings.set(settingsKey, {
    selection = self.selection,
    configuredDefault = self.configuredDefault,
  })
end

--- Resolve "system" to the configured light or dark theme id.
---@return string
function Theme:selectedThemeId()
  if self.selection ~= "system" then
    return self.selection
  end

  if hs.host.interfaceStyle() == "Dark" then
    return self.config.theme.system.dark
  end

  return self.config.theme.system.light
end

--- Refresh the active semantic color set from the selected theme.
function Theme:refreshAppearance()
  local id = self:selectedThemeId()
  local definition = assert(
    self.themes[id],
    "Gearbox: selected theme disappeared: " .. tostring(id)
  )

  local accent = definition.accent
  local accentText = definition.accentText

  if self.config.theme.accentSource == "system" then
    accent = self.systemAccent
    accentText = self.config.theme.systemAccentText
  end

  local selection = copyTable(accent)
  selection.alpha = definition.selectionAlpha

  self.activeThemeId = id
  self.colors = {
    background = definition.background,
    primary = definition.primary,
    secondary = definition.secondary,
    divider = definition.divider,
    accent = accent,
    accentText = accentText,
    selection = selection,
  }
end

--- Select a theme and refresh the active color set.
---@param selection string
function Theme:select(selection)
  assert(
    self:isValidSelection(selection),
    "Gearbox: unknown theme selection: " .. tostring(selection)
  )

  self.selection = selection
  self:persistSelection()
  self:refreshAppearance()
end

--- Return true when `selection` matches the current selection.
---@param selection string
---@return boolean
function Theme:isSelected(selection)
  return self.selection == selection
end

--- Build the generated "Themes" menu definition for `loader.lua`.
---@return table
function Theme:menuDefinition()
  local items = {
    {
      key = "s",
      label = "Follow macOS",
      kind = "action",
      action = {
        type = "setTheme",
        theme = "system",
      },
    },
    { divider = true },
  }

  for groupIndex, group in ipairs({ "light", "dark" }) do
    if groupIndex > 1 then
      table.insert(items, { divider = true })
    end

    for _, definition in ipairs(sortedThemes(self.themes, group)) do
      table.insert(items, {
        key = definition.key,
        label = definition.label,
        kind = "action",
        action = {
          type = "setTheme",
          theme = definition.id,
        },
      })
    end
  end

  return {
    id = "themes",
    title = "Themes",
    emoji = "🎨",
    parent = "leader",

    entry = {
      key = "t",
      label = "Themes",
      section = "utilities",
      sectionOrder = 200,
      order = 20,
    },

    items = items,
  }
end

--- Return a font table sized for the loupe animation.
---@param font table
---@param size number
---@return table
function Theme.resizedFont(font, size)
  local result = { size = size }

  if font.name then
    result.name = font.name
  end

  return result
end

--- Build styled text for a canvas element.
---@param text string
---@param font table
---@param color table
---@param alignment? string
---@return any
function Theme.styledText(text, font, color, alignment)
  return hs.styledtext.new(text, {
    font = font,
    color = color,
    paragraphStyle = {
      alignment = alignment or "left",
      lineBreak = "truncateTail",
    },
  })
end

return Theme
