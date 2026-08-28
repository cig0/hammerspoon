local Actions = require("Spoons.Gearbox.actions")
local Dependencies = require("Spoons.Gearbox.dependencies")
local HUD = require("Spoons.Gearbox.hud")
local Loader = require("Spoons.Gearbox.loader")
local Preferences = require("Spoons.Gearbox.preferences")
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
local currentConfigurationDialog

--- Show the intentionally disabled timeout without failing Hammerspoon setup.
local function showDisabledTimeoutDialog()
    if currentRuntime and currentRuntime.activeMenu then
        currentRuntime:endMenuSession()
    end

    local dialog
    dialog = Dependencies.retroUI().Dialog.show({
        theme = "borland",
        themeOverrides = {},
        title = "Gearbox configuration error",
        titleAlignment = "left",
        content = {
            {text = "Gearbox cannot start because `menu.timeout` is set to `0` (disabled).", role = "body"},
            {text = "Set `menu.timeout` to a positive number of seconds, then reload Hammerspoon.", role = "body"}
        },
        footer = {
            text = "This dialog will be dismissed in 30 seconds.",
            role = "notice",
            buttonId = "accept"
        },
        buttons = {{id = "accept", label = "Accept", hotkey = "a", default = true, enabled = true}},
        dismissAfter = 30,
        dismissOnEscape = false,
        dismissOnBackgroundClick = false,
        onDismiss = function()
            if currentConfigurationDialog == dialog then currentConfigurationDialog = nil end
        end
    })
    currentConfigurationDialog = dialog
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
---@return table|nil
function Gearbox.start(...)
    if currentConfigurationDialog then
        currentConfigurationDialog:delete()
        currentConfigurationDialog = nil
    end
    if select("#", ...) ~= 0 then
        error(
            "Gearbox: edit Spoons/Gearbox/config.lua instead of passing overrides",
            0)
    end

    local sourceConfig = require("Spoons.Gearbox.config")

    Validation.validateConfig(sourceConfig)

    if sourceConfig.menu.timeout == 0 then
        showDisabledTimeoutDialog()
        return currentRuntime
    end

    local directory = sourceDirectory()
    local preferences = Preferences.new(sourceConfig)
    local config = preferences.config

    Validation.validateConfig(config)

    local theme = Theme.new(config, directory)
    local scratchpad = config.scratchpad.enable and
                           Scratchpad.new(config, theme) or nil

    -- State-dependent menus stay with their owners; see menus/README.md.
    local menuDefinitions = {theme:menuDefinition()}

    for _, definition in ipairs(preferences:menuDefinitions()) do
        table.insert(menuDefinitions, definition)
    end

    local menus, rootId = Loader.load(directory, config, Actions,
                                      menuDefinitions, theme)
    local hud = HUD.new(config, theme)

    local candidateRuntime = Runtime.new(config, menus, rootId, Actions, theme,
                                         preferences, hud, scratchpad)

    candidateRuntime:start()

    if currentRuntime then currentRuntime:stop() end

    currentRuntime = candidateRuntime

    return currentRuntime
end

--- Stop the active Gearbox runtime, if any.
function Gearbox.stop()
    if currentConfigurationDialog then
        currentConfigurationDialog:delete()
        currentConfigurationDialog = nil
    end
    if currentRuntime then
        currentRuntime:stop()
        currentRuntime = nil
    end
end

return Gearbox
