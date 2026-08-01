--- RetroUI visual preset resolution.
local namespace = (...):match("^(.*)%.theme$")
local Validation = require(namespace .. ".validation")
local Theme = {}

local white = {white = 1, alpha = 1}
local black = {white = 0, alpha = 1}
local buttonStyle = {faceColor = white, textColor = black, hotkeyColor = black}
local weights = {regular = true, bold = true}
local defaults = {
    id = "", label = "",
    typography = {family = "Menlo", bodySize = 18, titleWeight = "bold", bodyWeight = "regular", noticeWeight = "bold", buttonWeight = "bold"},
    dialog = {backgroundColor = black, bodyTextColor = white, noticeTextColor = white, titleTextColor = white, hotkeyTextColor = white, outerPadding = {top = 18, bottom = 18, left = 22, right = 22}},
    frame = {borderColor = white, style = "double", titleAlignment = "center", padding = {top = 1, bottom = 1, left = 2, right = 2}},
    button = {gap = 16, padding = {top = 7, bottom = 7, left = 18, right = 18}, shadowOffset = {x = 4, y = 4}, pressOffset = {x = 4, y = 4}, releaseDelay = 0.06, normal = buttonStyle, hovered = buttonStyle, focused = buttonStyle, pressed = buttonStyle, disabled = buttonStyle, shadowColor = black}
}

local function isColor(value)
    return type(value) == "table" and value.alpha ~= nil and (value.white ~= nil or value.red ~= nil or value.green ~= nil or value.blue ~= nil)
end

local function merge(base, override, name)
    if override == nil then return Validation.copy(base) end
    Validation.type(override, "table", name)
    if isColor(base) then return Validation.copy(override) end
    local result = Validation.copy(base)
    for key, value in pairs(override) do
        if result[key] == nil then Validation.fail(name .. " has unknown field: " .. key, 3) end
        if type(result[key]) == "table" then
            result[key] = merge(result[key], value, name .. "." .. key)
        else
            result[key] = Validation.copy(value)
        end
    end
    return result
end

local function validatePadding(value, name)
    Validation.type(value, "table", name)
    Validation.exactKeys(value, {top = true, bottom = true, left = true, right = true}, name)
    for _, key in ipairs({"top", "bottom", "left", "right"}) do Validation.nonNegativeNumber(value[key], name .. "." .. key) end
end

local function validateOffset(value, name)
    Validation.type(value, "table", name)
    Validation.exactKeys(value, {x = true, y = true}, name)
    Validation.nonNegativeNumber(value.x, name .. ".x")
    Validation.nonNegativeNumber(value.y, name .. ".y")
end

local function validateTheme(value)
    Validation.type(value, "table", "theme")
    Validation.type(value.id, "string", "theme.id")
    Validation.type(value.label, "string", "theme.label")
    if value.id == "" then Validation.fail("theme.id cannot be empty", 2) end
    if value.label == "" then Validation.fail("theme.label cannot be empty", 2) end
    Validation.type(value.typography.family, "string", "theme.typography.family")
    if value.typography.family == "" then Validation.fail("theme.typography.family cannot be empty", 2) end
    Validation.positiveNumber(value.typography.bodySize, "theme.typography.bodySize")
    for _, field in ipairs({"titleWeight", "bodyWeight", "noticeWeight", "buttonWeight"}) do
        Validation.enum(value.typography[field], weights,
                        "theme.typography." .. field)
    end
    validatePadding(value.dialog.outerPadding, "theme.dialog.outerPadding")
    Validation.enum(value.frame.style, {single = true, double = true}, "theme.frame.style")
    Validation.enum(value.frame.titleAlignment, {left = true, center = true, right = true}, "theme.frame.titleAlignment")
    validatePadding(value.frame.padding, "theme.frame.padding")
    for _, field in ipairs({"backgroundColor", "bodyTextColor", "noticeTextColor", "titleTextColor", "hotkeyTextColor"}) do Validation.color(value.dialog[field], "theme.dialog." .. field) end
    Validation.color(value.frame.borderColor, "theme.frame.borderColor")
    for _, state in ipairs({"normal", "hovered", "focused", "pressed", "disabled"}) do
        local style = value.button[state]
        Validation.type(style, "table", "theme.button." .. state)
        for _, field in ipairs({"faceColor", "textColor", "hotkeyColor"}) do Validation.color(style[field], "theme.button." .. state .. "." .. field) end
    end
    Validation.color(value.button.shadowColor, "theme.button.shadowColor")
    validatePadding(value.button.padding, "theme.button.padding")
    validateOffset(value.button.shadowOffset, "theme.button.shadowOffset")
    validateOffset(value.button.pressOffset, "theme.button.pressOffset")
    Validation.nonNegativeNumber(value.button.gap, "theme.button.gap")
    Validation.positiveNumber(value.button.releaseDelay, "theme.button.releaseDelay")
end

function Theme.resolve(name, overrides)
    Validation.type(name, "string", "theme name")
    if not name:match("^[%w_-]+$") then Validation.fail("unknown theme: " .. name, 2) end
    local moduleName = namespace .. ".themes." .. name
    if package.loaded[moduleName] == nil and package.preload[moduleName] == nil and
        not package.searchpath(moduleName, package.path) then
        Validation.fail("unknown theme: " .. name, 2)
    end
    local preset = require(moduleName)
    local resolved = merge(defaults, preset, "theme")
    resolved = merge(resolved, overrides or {}, "theme")
    validateTheme(resolved)
    return resolved
end

return Theme
