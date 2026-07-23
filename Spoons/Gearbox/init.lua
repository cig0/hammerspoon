local Actions = require("Spoons.Gearbox.actions")
local HUD = require("Spoons.Gearbox.hud")
local Loader = require("Spoons.Gearbox.loader")
local Runtime = require("Spoons.Gearbox.runtime")
local Scratchpad = require("Spoons.Gearbox.scratchpad")
local Theme = require("Spoons.Gearbox.theme")

local Gearbox = {}
local currentRuntime

local positions = {
  top = true,
  center = true,
  bottom = true,
}

local screens = {
  main = true,
  mouse = true,
}

local accentSources = {
  system = true,
  theme = true,
}

local fontWeights = {
  regular = true,
  bold = true,
}

local hotkeyModifiers = {
  alt = true,
  option = true,
  cmd = true,
  command = true,
  ctrl = true,
  control = true,
  shift = true,
}

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

local function isArray(value)
  return type(value) == "table" and value[1] ~= nil
end

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

local function merge(base, overrides)
  local result = copyTable(base)

  for key, value in pairs(overrides or {}) do
    local baseColorModel = colorModel(result[key])
    local overrideColorModel = colorModel(value)

    if baseColorModel
        and overrideColorModel
        and baseColorModel ~= overrideColorModel then
      result[key] = copyTable(value)

      if result[key].alpha == nil then
        result[key].alpha = base[key].alpha
      end
    elseif type(value) == "table"
        and type(result[key]) == "table"
        and not isArray(value)
        and not isArray(result[key]) then
      result[key] = merge(result[key], value)
    else
      result[key] = copyTable(value)
    end
  end

  return result
end

local function assertType(value, expectedType, name)
  assert(
    type(value) == expectedType,
    ("Gearbox: %s must be a %s"):format(name, expectedType)
  )
end

local function validateColor(color, name)
  assertType(color, "table", name)
  local model = colorModel(color)

  assert(
    model ~= "mixed",
    "Gearbox: " .. name .. " cannot mix white with RGB components"
  )

  assert(
    model == "grayscale" or model == "rgb",
    "Gearbox: " .. name .. " must define white or red, green, and blue"
  )

  if model == "grayscale" then
    assertType(color.white, "number", name .. ".white")
    assert(color.white >= 0 and color.white <= 1, name .. ".white must be 0..1")
  else
    for _, component in ipairs({ "red", "green", "blue" }) do
      assertType(color[component], "number", name .. "." .. component)
      assert(
        color[component] >= 0 and color[component] <= 1,
        name .. "." .. component .. " must be 0..1"
      )
    end
  end

  assertType(color.alpha, "number", name .. ".alpha")
  assert(color.alpha >= 0 and color.alpha <= 1, name .. ".alpha must be 0..1")
end

local function validHotkeyKey(key)
  if key:match("^#%d+$") then
    return true
  end

  return hs.keycodes.map[key:lower()] ~= nil
end

local function keyIdentity(key)
  if key:match("^#%d+$") then
    return "#" .. tonumber(key:sub(2))
  end

  return key:lower()
end

local function validateConfig(config)
  assertType(config.hotkey.modifiers, "table", "hotkey.modifiers")
  assert(#config.hotkey.modifiers > 0, "Gearbox: hotkey.modifiers cannot be empty")

  for index, modifier in ipairs(config.hotkey.modifiers) do
    assertType(modifier, "string", "hotkey.modifiers[" .. index .. "]")
    assert(
      hotkeyModifiers[modifier],
      "Gearbox: invalid hotkey modifier: " .. modifier
    )
  end

  assertType(config.hotkey.key, "string", "hotkey.key")
  assert(config.hotkey.key ~= "", "Gearbox: hotkey.key cannot be empty")
  assert(
    validHotkeyKey(config.hotkey.key),
    "Gearbox: invalid hotkey key: " .. config.hotkey.key
  )

  assertType(config.menu.timeout, "number", "menu.timeout")
  assert(config.menu.timeout >= 0, "Gearbox: menu.timeout cannot be negative")
  assert(positions[config.menu.position], "Gearbox: invalid menu.position")
  assert(screens[config.menu.screen], "Gearbox: invalid menu.screen")
  assertType(config.menu.width, "number", "menu.width")
  assert(config.menu.width >= 200, "Gearbox: menu.width must be at least 200")
  assertType(config.menu.showEmojis, "boolean", "menu.showEmojis")
  assertType(config.menu.highlightGroups, "boolean", "menu.highlightGroups")

  if config.font.family ~= nil then
    assertType(config.font.family, "string", "font.family")
  end

  assertType(config.font.size, "number", "font.size")
  assert(config.font.size > 0, "Gearbox: font.size must be positive")
  assertType(config.font.titleSize, "number", "font.titleSize")
  assert(config.font.titleSize > 0, "Gearbox: font.titleSize must be positive")
  assert(fontWeights[config.font.bodyWeight], "Gearbox: invalid font.bodyWeight")
  assert(fontWeights[config.font.groupWeight], "Gearbox: invalid font.groupWeight")
  assert(fontWeights[config.font.titleWeight], "Gearbox: invalid font.titleWeight")

  assertType(config.loupe.enabled, "boolean", "loupe.enabled")
  assertType(config.loupe.selectedScale, "number", "loupe.selectedScale")
  assert(config.loupe.selectedScale >= 1, "Gearbox: loupe.selectedScale must be >= 1")
  assertType(config.loupe.adjacentScale, "number", "loupe.adjacentScale")
  assert(config.loupe.adjacentScale >= 1, "Gearbox: loupe.adjacentScale must be >= 1")
  assert(
    config.loupe.adjacentScale <= config.loupe.selectedScale,
    "Gearbox: adjacentScale cannot exceed selectedScale"
  )
  assertType(config.loupe.duration, "number", "loupe.duration")
  assert(config.loupe.duration >= 0, "Gearbox: loupe.duration cannot be negative")

  assertType(config.theme.name, "string", "theme.name")
  assert(config.theme.name ~= "", "Gearbox: theme.name cannot be empty")
  assertType(
    config.theme.persistSelection,
    "boolean",
    "theme.persistSelection"
  )
  assertType(config.theme.system, "table", "theme.system")
  assertType(config.theme.system.dark, "string", "theme.system.dark")
  assert(
    config.theme.system.dark ~= "",
    "Gearbox: theme.system.dark cannot be empty"
  )
  assertType(config.theme.system.light, "string", "theme.system.light")
  assert(
    config.theme.system.light ~= "",
    "Gearbox: theme.system.light cannot be empty"
  )
  assert(
    accentSources[config.theme.accentSource],
    "Gearbox: theme.accentSource must be system or theme"
  )
  validateColor(config.theme.fallbackAccent, "theme.fallbackAccent")
  assert(
    colorModel(config.theme.fallbackAccent) == "rgb",
    "Gearbox: theme.fallbackAccent must use RGB components"
  )
  validateColor(config.theme.systemAccentText, "theme.systemAccentText")
  assertType(config.theme.overrides, "table", "theme.overrides")

  assertType(config.navigation.enabled, "boolean", "navigation.enabled")
  assertType(config.navigation.wrap, "boolean", "navigation.wrap")
  assertType(config.navigation.activateKey, "string", "navigation.activateKey")
  assertType(config.navigation.cancelKey, "string", "navigation.cancelKey")
  assert(
    config.navigation.cancelKey ~= "",
    "Gearbox: navigation.cancelKey cannot be empty"
  )
  assert(
    validHotkeyKey(config.navigation.cancelKey),
    "Gearbox: invalid navigation.cancelKey: "
        .. config.navigation.cancelKey
  )
  if config.navigation.enabled then
    assert(
      config.navigation.activateKey ~= "",
      "Gearbox: navigation.activateKey cannot be empty"
    )
    assert(
      validHotkeyKey(config.navigation.activateKey),
      "Gearbox: invalid navigation.activateKey: "
          .. config.navigation.activateKey
    )
    assert(
      keyIdentity(config.navigation.activateKey)
          ~= keyIdentity(config.navigation.cancelKey),
      "Gearbox: navigation activate and cancel keys must differ"
    )
    assert(
      keyIdentity(config.navigation.activateKey) ~= "up"
          and keyIdentity(config.navigation.activateKey) ~= "down",
      "Gearbox: navigation.activateKey cannot be up or down"
    )
  end
  assertType(config.navigation.includeFooter, "boolean", "navigation.includeFooter")
  assertType(
    config.navigation.resetTimeoutOnInput,
    "boolean",
    "navigation.resetTimeoutOnInput"
  )

  assertType(config.scratchpad.enable, "boolean", "scratchpad.enable")
  assertType(config.scratchpad.menuKey, "string", "scratchpad.menuKey")
  assert(
    config.scratchpad.menuKey ~= "",
    "Gearbox: scratchpad.menuKey cannot be empty"
  )
  assert(
    validHotkeyKey(config.scratchpad.menuKey),
    "Gearbox: invalid scratchpad.menuKey: "
        .. config.scratchpad.menuKey
  )
  assertType(config.scratchpad.width, "number", "scratchpad.width")
  assert(
    config.scratchpad.width >= 360,
    "Gearbox: scratchpad.width must be at least 360"
  )
  assertType(config.scratchpad.height, "number", "scratchpad.height")
  assert(
    config.scratchpad.height >= 240,
    "Gearbox: scratchpad.height must be at least 240"
  )
  assertType(
    config.scratchpad.maxCharacters,
    "number",
    "scratchpad.maxCharacters"
  )
  assert(
    config.scratchpad.maxCharacters >= 1
        and config.scratchpad.maxCharacters % 1 == 0,
    "Gearbox: scratchpad.maxCharacters must be a positive integer"
  )
  assertType(
    config.scratchpad.persistContent,
    "boolean",
    "scratchpad.persistContent"
  )
  assertType(
    config.scratchpad.showInstructions,
    "boolean",
    "scratchpad.showInstructions"
  )
end

local function sourceDirectory()
  local source = debug.getinfo(1, "S").source

  assert(
    source:sub(1, 1) == "@",
    "Gearbox: cannot determine module directory"
  )

  local directory = source:sub(2):match("^(.*)/init%.lua$")
  assert(directory, "Gearbox: cannot determine module directory")

  return directory
end

function Gearbox.start(overrides)
  local defaults = require("Spoons.Gearbox.config")
  local config = merge(defaults, overrides or {})
  local directory = sourceDirectory()

  validateConfig(config)

  local theme = Theme.new(config, directory)
  local scratchpad = config.scratchpad.enable
      and Scratchpad.new(config, theme)
      or nil

  local supplementalItems = scratchpad
      and {
        leader = {
          scratchpad:menuItem(),
        },
      }
      or nil

  local menus, rootId = Loader.load(
    directory,
    config,
    Actions,
    { theme:menuDefinition() },
    theme,
    supplementalItems
  )
  local hud = HUD.new(config, theme)

  local candidateRuntime = Runtime.new(
    config,
    menus,
    rootId,
    Actions,
    theme,
    hud,
    scratchpad
  )

  candidateRuntime:start()

  if currentRuntime then
    currentRuntime:stop()
  end

  currentRuntime = candidateRuntime

  return currentRuntime
end

function Gearbox.stop()
  if currentRuntime then
    currentRuntime:stop()
    currentRuntime = nil
  end
end

return Gearbox
