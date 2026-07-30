local Actions = require("Spoons.Gearbox.actions")
local HUD = require("Spoons.Gearbox.hud")
local Loader = require("Spoons.Gearbox.loader")
local Runtime = require("Spoons.Gearbox.runtime")
local Scratchpad = require("Spoons.Gearbox.scratchpad")
local Theme = require("Spoons.Gearbox.theme")
local Validation = require("Spoons.Gearbox.validation")

--- Gearbox public API.
--
-- Loads and validates the authoritative config, then wires together theme
-- discovery, menu loading, the modal runtime, and the canvas HUD.
local Gearbox = {}
local currentRuntime

local disabledTimeoutAlertDuration = 10

local disabledTimeoutAlertTitle = " Gearbox configuration error "

local disabledTimeoutAlertBody = {
    "Gearbox cannot start because `menu.timeout` is set to `0` (disabled).",
    "Set `menu.timeout` to a positive number of seconds, then reload Hammerspoon."
}

local disabledTimeoutAlertLegend =
    "This window will be dismissed in 10 seconds."

--- Build a padded DOS-style warning box around the disabled-timeout message.
---@return string beforeLegend
---@return string legend
---@return string afterLegend
local function disabledTimeoutAlertBox()
    local horizontalPadding = 2
    local contentWidth = #disabledTimeoutAlertLegend

    for _, line in ipairs(disabledTimeoutAlertBody) do
        contentWidth = math.max(contentWidth, #line)
    end

    local innerWidth = contentWidth + horizontalPadding * 2
    local title = "═[" .. disabledTimeoutAlertTitle .. "]"
    local titleWidth = #disabledTimeoutAlertTitle + 3
    local top = "╔" .. title ..
                    string.rep("═", innerWidth - titleWidth) .. "╗"
    local bottom = "╚" .. string.rep("═", innerWidth) .. "╝"
    local blank = "║" .. string.rep(" ", innerWidth) .. "║"

    local function row(line)
        return "║" .. string.rep(" ", horizontalPadding) .. line ..
                   string.rep(" ",
                              innerWidth - horizontalPadding - #line) .. "║"
    end

    local beforeLegend = {top, blank}

    for _, line in ipairs(disabledTimeoutAlertBody) do
        table.insert(beforeLegend, row(line))
    end

    table.insert(beforeLegend, blank)

    local legendPrefix =
        "║" .. string.rep(" ", horizontalPadding)
    local legendSuffix =
        string.rep(" ",
                   innerWidth - horizontalPadding -
                       #disabledTimeoutAlertLegend) .. "║"

    return table.concat(beforeLegend, "\n") .. "\n" .. legendPrefix,
           disabledTimeoutAlertLegend,
           legendSuffix .. "\n" .. blank .. "\n" .. bottom
end

--- Report the intentionally disabled timeout and abort Gearbox startup.
---@param config table
local function failDisabledTimeout(config)
    local textSize = math.max(config.font.titleSize + 2,
                              hs.alert.defaultStyle.textSize)
    local font = {name = "Menlo", size = textSize}
    local white = {white = 1, alpha = 1}
    local paragraphStyle = {alignment = "left", lineBreak = "clip"}
    local beforeLegend, legend, afterLegend = disabledTimeoutAlertBox()
    local regularAttributes = {
        font = font,
        color = white,
        paragraphStyle = paragraphStyle
    }
    local legendAttributes = {
        font = hs.styledtext.convertFont(font, true),
        color = {red = 1, green = 0.9, blue = 0, alpha = 1},
        paragraphStyle = paragraphStyle
    }
    local message = hs.styledtext.new(beforeLegend, regularAttributes) ..
                        hs.styledtext.new(legend, legendAttributes) ..
                        hs.styledtext.new(afterLegend, regularAttributes)
    local style = {
        fillColor = {red = 0.72, green = 0, blue = 0, alpha = 0.98},
        strokeWidth = 0,
        textColor = white,
        textSize = textSize,
        radius = 0,
        padding = textSize
    }

    hs.alert.show(message, style, disabledTimeoutAlertDuration)
    error("Gearbox: menu.timeout must be greater than zero", 0)
end

--- Locate this Spoon's source directory from `debug.getinfo`.
---@return string
local function sourceDirectory()
    local source = debug.getinfo(1, "S").source

    assert(source:sub(1, 1) == "@", "Gearbox: cannot determine module directory")

    local directory = source:sub(2):match("^(.*)/init%.lua$")
    assert(directory, "Gearbox: cannot determine module directory")

    return directory
end

--- Start Gearbox from its authoritative configuration module.
---@return table
function Gearbox.start(...)
    if select("#", ...) ~= 0 then
        error(
            "Gearbox: edit Spoons/Gearbox/config.lua instead of passing overrides",
            0)
    end

    local config = require("Spoons.Gearbox.config")

    Validation.validateConfig(config)

    if config.menu.timeout == 0 then failDisabledTimeout(config) end

    local directory = sourceDirectory()
    local theme = Theme.new(config, directory)
    local scratchpad = config.scratchpad.enable and
                           Scratchpad.new(config, theme) or nil

    local menus, rootId = Loader.load(directory, config, Actions,
                                      {theme:menuDefinition()}, theme)
    local hud = HUD.new(config, theme)

    local candidateRuntime = Runtime.new(config, menus, rootId, Actions, theme,
                                         hud, scratchpad)

    candidateRuntime:start()

    if currentRuntime then currentRuntime:stop() end

    currentRuntime = candidateRuntime

    return currentRuntime
end

--- Stop the active Gearbox runtime, if any.
function Gearbox.stop()
    if currentRuntime then
        currentRuntime:stop()
        currentRuntime = nil
    end
end

return Gearbox
