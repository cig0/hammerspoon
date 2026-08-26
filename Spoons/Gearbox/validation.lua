--- Shared Gearbox value and configuration validation.
--
-- Domain-specific menu and theme graph checks remain in their owning modules.
local Validation = {}

local positions = {top = true, center = true, bottom = true}

local screens = {main = true, mouse = true}

local accentSources = {system = true, theme = true}

local fontWeights = {regular = true, bold = true}

local hotkeyModifiers = {
    alt = true,
    option = true,
    cmd = true,
    command = true,
    ctrl = true,
    control = true,
    shift = true
}

--- Classify a color table as "grayscale", "rgb", "mixed", or nil.
---@param value any
---@return "grayscale"|"rgb"|"mixed"|nil
local function colorModel(value)
    if type(value) ~= "table" then return nil end

    local hasWhite = value.white ~= nil
    local hasRGB = value.red ~= nil or value.green ~= nil or value.blue ~= nil

    if hasWhite and hasRGB then return "mixed" end

    if hasWhite then return "grayscale" end

    if hasRGB then return "rgb" end

    return nil
end

--- Assert that `value` has the expected Lua type.
---@param value any
---@param expectedType string
---@param name string
local function assertType(value, expectedType, name)
    assert(type(value) == expectedType,
           ("Gearbox: %s must be a %s"):format(name, expectedType))
end

--- Raise a Gearbox-prefixed validation error.
---@param message string
local function fail(message) error("Gearbox: " .. message, 3) end

--- Validate that `value` is a number in [0, 1].
---@param value any
---@param name string
local function validateUnit(value, name)
    if type(value) ~= "number" or value < 0 or value > 1 then
        fail(name .. " must be a number from 0 to 1")
    end
end

--- Validate a color table without mutating it.
---@param color table
---@param name string
---@param options? {requireAlpha?: boolean, configMessages?: boolean}
function Validation.validateColor(color, name, options)
    options = options or {}

    if options.configMessages then
        assertType(color, "table", name)
    elseif type(color) ~= "table" then
        fail(name .. " must be a color table")
    end

    local model = colorModel(color)

    if options.configMessages then
        assert(model ~= "mixed",
               "Gearbox: " .. name .. " cannot mix white with RGB components")

        assert(model == "grayscale" or model == "rgb",
               "Gearbox: " .. name ..
                   " must define white or red, green, and blue")
    else
        if model == "mixed" then
            fail(name .. " cannot mix white with RGB components")
        end

        if model ~= "grayscale" and model ~= "rgb" then
            fail(name .. " must define white or red, green, and blue")
        end
    end

    local components = model == "grayscale" and {"white"} or
                           {"red", "green", "blue"}

    for _, component in ipairs(components) do
        local componentName = name .. "." .. component

        if options.configMessages then
            assertType(color[component], "number", componentName)
            assert(color[component] >= 0 and color[component] <= 1,
                   componentName .. " must be 0..1")
        else
            validateUnit(color[component], componentName)
        end
    end

    if options.configMessages then
        assertType(color.alpha, "number", name .. ".alpha")
        assert(color.alpha >= 0 and color.alpha <= 1,
               name .. ".alpha must be 0..1")
    else
        if options.requireAlpha and color.alpha == nil then
            fail(name .. ".alpha is required")
        end

        if color.alpha ~= nil then validateUnit(color.alpha, name .. ".alpha") end
    end

    return model
end

--- Return true when `key` is a valid Hammerspoon key name.
---@param key any
---@return boolean
function Validation.isHotkeyKey(key)
    if type(key) ~= "string" then return false end

    if key:match("^#%d+$") then return true end

    return hs.keycodes.map[key:lower()] ~= nil
end

--- Normalize a key string for duplicate and reserved-key detection.
---@param key string
---@return string
function Validation.keyIdentity(key)
    if key:match("^#%d+$") then return "#" .. tonumber(key:sub(2)) end

    return key:lower()
end

--- Validate the authoritative Gearbox configuration.
---@param config table
function Validation.validateConfig(config)
    assertType(config.hotkey.modifiers, "table", "hotkey.modifiers")
    assert(#config.hotkey.modifiers > 0,
           "Gearbox: hotkey.modifiers cannot be empty")

    for index, modifier in ipairs(config.hotkey.modifiers) do
        assertType(modifier, "string", "hotkey.modifiers[" .. index .. "]")
        assert(hotkeyModifiers[modifier],
               "Gearbox: invalid hotkey modifier: " .. modifier)
    end

    assertType(config.hotkey.key, "string", "hotkey.key")
    assert(config.hotkey.key ~= "", "Gearbox: hotkey.key cannot be empty")
    assert(Validation.isHotkeyKey(config.hotkey.key),
           "Gearbox: invalid hotkey key: " .. config.hotkey.key)

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
    assert(fontWeights[config.font.bodyWeight],
           "Gearbox: invalid font.bodyWeight")
    assert(fontWeights[config.font.groupWeight],
           "Gearbox: invalid font.groupWeight")
    assert(fontWeights[config.font.titleWeight],
           "Gearbox: invalid font.titleWeight")

    assertType(config.loupe.enabled, "boolean", "loupe.enabled")
    assertType(config.loupe.selectedScale, "number", "loupe.selectedScale")
    assert(config.loupe.selectedScale >= 1,
           "Gearbox: loupe.selectedScale must be >= 1")
    assertType(config.loupe.adjacentScale, "number", "loupe.adjacentScale")
    assert(config.loupe.adjacentScale >= 1,
           "Gearbox: loupe.adjacentScale must be >= 1")
    assert(config.loupe.adjacentScale <= config.loupe.selectedScale,
           "Gearbox: adjacentScale cannot exceed selectedScale")
    assertType(config.loupe.duration, "number", "loupe.duration")
    assert(config.loupe.duration >= 0,
           "Gearbox: loupe.duration cannot be negative")

    assertType(config.theme.name, "string", "theme.name")
    assert(config.theme.name ~= "", "Gearbox: theme.name cannot be empty")
    assertType(config.theme.persistSelection, "boolean",
               "theme.persistSelection")
    assertType(config.theme.system, "table", "theme.system")
    assertType(config.theme.system.dark, "string", "theme.system.dark")
    assert(config.theme.system.dark ~= "",
           "Gearbox: theme.system.dark cannot be empty")
    assertType(config.theme.system.light, "string", "theme.system.light")
    assert(config.theme.system.light ~= "",
           "Gearbox: theme.system.light cannot be empty")
    assert(accentSources[config.theme.accentSource],
           "Gearbox: theme.accentSource must be system or theme")

    local fallbackModel = Validation.validateColor(
                              config.theme.fallbackAccent,
                              "theme.fallbackAccent",
                              {configMessages = true})

    assert(fallbackModel == "rgb",
           "Gearbox: theme.fallbackAccent must use RGB components")

    Validation.validateColor(config.theme.systemAccentText,
                             "theme.systemAccentText",
                             {configMessages = true})

    assertType(config.theme.overrides, "table", "theme.overrides")

    assertType(config.navigation.enabled, "boolean", "navigation.enabled")
    assertType(config.navigation.wrap, "boolean", "navigation.wrap")
    assertType(config.navigation.activateKey, "string", "navigation.activateKey")
    assertType(config.navigation.cancelKey, "string", "navigation.cancelKey")
    assert(config.navigation.cancelKey ~= "",
           "Gearbox: navigation.cancelKey cannot be empty")
    assert(Validation.isHotkeyKey(config.navigation.cancelKey),
           "Gearbox: invalid navigation.cancelKey: " ..
               config.navigation.cancelKey)

    if config.navigation.enabled then
        assert(config.navigation.activateKey ~= "",
               "Gearbox: navigation.activateKey cannot be empty")
        assert(Validation.isHotkeyKey(config.navigation.activateKey),
               "Gearbox: invalid navigation.activateKey: " ..
                   config.navigation.activateKey)
        assert(Validation.keyIdentity(config.navigation.activateKey) ~=
                   Validation.keyIdentity(config.navigation.cancelKey),
               "Gearbox: navigation activate and cancel keys must differ")
        assert(Validation.keyIdentity(config.navigation.activateKey) ~= "up" and
                   Validation.keyIdentity(config.navigation.activateKey) ~=
                   "down",
               "Gearbox: navigation.activateKey cannot be up or down")
    end

    assertType(config.navigation.includeFooter, "boolean",
               "navigation.includeFooter")
    assertType(config.navigation.resetTimeoutOnInput, "boolean",
               "navigation.resetTimeoutOnInput")

    assertType(config.scratchpad.enable, "boolean", "scratchpad.enable")
    assertType(config.scratchpad.fontSize, "number", "scratchpad.fontSize")
    assert(config.scratchpad.fontSize > 0,
           "Gearbox: scratchpad.fontSize must be positive")
    assertType(config.scratchpad.width, "number", "scratchpad.width")
    assert(config.scratchpad.width >= 360,
           "Gearbox: scratchpad.width must be at least 360")
    assertType(config.scratchpad.height, "number", "scratchpad.height")
    assert(config.scratchpad.height >= 240,
           "Gearbox: scratchpad.height must be at least 240")
    assertType(config.scratchpad.maxCharacters, "number",
               "scratchpad.maxCharacters")
    assert(config.scratchpad.maxCharacters >= 1 and
               config.scratchpad.maxCharacters % 1 == 0,
           "Gearbox: scratchpad.maxCharacters must be a positive integer")
    assertType(config.scratchpad.persistContent, "boolean",
               "scratchpad.persistContent")

    if config.scratchpad.storagePath ~= nil then
        assertType(config.scratchpad.storagePath, "string",
                   "scratchpad.storagePath")
        assert(config.scratchpad.storagePath:sub(1, 1) == "/" or
                   config.scratchpad.storagePath:sub(1, 2) == "~/",
               "Gearbox: scratchpad.storagePath must be absolute or begin with ~/")
    end

    assertType(config.scratchpad.showInstructions, "boolean",
               "scratchpad.showInstructions")
end

return Validation
