local root = assert(arg[1], "repository root argument is required")

package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local caffeinateState = {displayIdle = false, systemIdle = false}

local createdCanvases = {}
local createdModals = {}
local createdTimers = {}
local createdWebviews = {}
local createdWebviewControllers = {}
local shownAlerts = {}
local globalHotkeyPressed
local globalHotkeyBindCalls = 0
local launchedApplication
local defaultTextStyleCalls = 0
local failNextModalBind = false
local failNextGlobalHotkey = false
local interfaceStyle = "Dark"
local interfaceStyleCalls = 0
local osascriptCalls = 0
local reloadCalls = 0
local settings = {}

local styledTextMetatable = {}

local function styledText(text, attributes)
    return setmetatable({
        text = text,
        segments = {{text = text, attributes = attributes}}
    }, styledTextMetatable)
end

local function styledTextValue(value)
    if getmetatable(value) == styledTextMetatable then return value.text end

    return value
end

styledTextMetatable.__concat = function(left, right)
    local result = styledText("", nil)
    result.segments = {}

    for _, value in ipairs({left, right}) do
        if getmetatable(value) == styledTextMetatable then
            result.text = result.text .. value.text

            for _, segment in ipairs(value.segments) do
                table.insert(result.segments, segment)
            end
        else
            result.text = result.text .. tostring(value)
            table.insert(result.segments, {text = tostring(value)})
        end
    end

    return result
end

local function newModal()
    local modal = {bindings = {}, bindingCalls = {}}

    function modal:bind(modifiers, key, message, pressed, released, repeated)
        if failNextModalBind then
            failNextModalBind = false
            error("simulated modal binding failure")
        end

        if message == nil or type(message) == "function" then
            repeated = released
            released = pressed
            pressed = message
            message = nil
        end

        table.insert(self.bindingCalls, {
            modifiers = modifiers,
            key = key,
            pressed = pressed,
            released = released,
            repeated = repeated
        })

        self.bindings[key] = pressed or released or repeated
        return self
    end

    function modal:enter()
        if self.entered then self.entered() end
        return self
    end

    function modal:exit()
        if self.exited then self.exited() end
        return self
    end

    function modal:delete() self.deleted = true end

    return modal
end

local function newCanvas()
    local canvas = {elements = {}}

    function canvas:appendElements(elements)
        self.elements = elements
        return self
    end

    function canvas:elementAttribute(index, attribute, value)
        self.elements[index][attribute] = value
        return self
    end

    function canvas:wantsLayer() return self end

    function canvas:show()
        self.visible = true
        return self
    end

    function canvas:delete() self.visible = false end

    table.insert(createdCanvases, canvas)
    return canvas
end

local function newWebview(frame, controller)
    local webview = {
        currentFrame = frame,
        controller = controller,
        evaluatedScripts = {},
        visible = false
    }

    local function chain(name)
        webview[name] = function(self, value)
            self[name .. "Value"] = value
            return self
        end
    end

    for _, name in ipairs({
        "allowGestures", "allowNewWindows", "allowTextEntry", "deleteOnClose",
        "shadow", "transparent", "windowStyle"
    }) do chain(name) end

    function webview:bringToFront()
        self.broughtToFront = true
        return self
    end

    function webview:delete()
        self.deleted = true
        self.visible = false
    end

    function webview:evaluateJavaScript(script, callback)
        table.insert(self.evaluatedScripts, script)

        if callback then callback(self.contentResult, nil) end

        return self
    end

    function webview:frame(value)
        if value then
            self.currentFrame = value
            return self
        end

        return self.currentFrame
    end

    function webview:hide()
        self.visible = false
        return self
    end

    function webview:hswindow()
        return {focus = function() self.focused = true end}
    end

    function webview:html(value)
        self.document = value

        if self.navigationCallbackValue then
            self.navigationCallbackValue("didFinishNavigation", self,
                                         "mock-navigation")
        end

        return self
    end

    function webview:isVisible() return self.visible end

    function webview:navigationCallback(callback)
        self.navigationCallbackValue = callback
        return self
    end

    function webview:show()
        self.visible = true
        return self
    end

    table.insert(createdWebviews, webview)
    return webview
end

hs = {
    alert = {
        defaultStyle = {textFont = ".AppleSystemUIFont", textSize = 27},
        show = function(message, style, duration)
            table.insert(shownAlerts, {
                message = message,
                style = style,
                duration = duration
            })
        end
    },

    application = {
        launchOrFocus = function(name) launchedApplication = name end
    },

    canvas = {
        defaultTextStyle = function()
            defaultTextStyleCalls = defaultTextStyleCalls + 1

            return {font = {name = "System", size = 14}}
        end,
        new = function() return newCanvas() end
    },

    caffeinate = {
        get = function(kind) return caffeinateState[kind] end,
        set = function(kind, value) caffeinateState[kind] = value end,
        systemSleep = function() end
    },

    fs = {
        dir = function(path)
            local process = assert(io.popen(("/bin/ls -a1 %q"):format(path)))
            local closed = false

            return function()
                local file = process:read("*l")

                if not file and not closed then
                    process:close()
                    closed = true
                end

                return file
            end
        end
    },

    hotkey = {
        bind = function(_, _, callback)
            globalHotkeyBindCalls = globalHotkeyBindCalls + 1

            if failNextGlobalHotkey then
                failNextGlobalHotkey = false
                return nil
            end

            globalHotkeyPressed = callback
            return {delete = function(self) self.deleted = true end}
        end,
        modal = {
            new = function()
                local modal = newModal()
                table.insert(createdModals, modal)
                return modal
            end
        }
    },

    host = {
        interfaceStyle = function()
            interfaceStyleCalls = interfaceStyleCalls + 1
            return interfaceStyle
        end
    },

    json = {
        decode = function(value)
            if value == "system-accent" then
                return {red = 0.2, green = 0.3, blue = 0.4, alpha = 1}
            end

            return nil
        end,
        encode = function() return "{}" end
    },

    keycodes = {
        map = setmetatable({
            down = 125,
            escape = 53,
            ["return"] = 36,
            space = 49,
            up = 126
        }, {
            __index = function(_, key)
                if key:match("^[a-z0-9]$") then return 1 end
            end
        })
    },

    mouse = {getCurrentScreen = function() return nil end},

    open = function() return true end,

    reload = function() reloadCalls = reloadCalls + 1 end,

    osascript = {
        javascript = function()
            osascriptCalls = osascriptCalls + 1
            return true, "system-accent"
        end
    },

    screen = {
        mainScreen = function()
            return {
                frame = function()
                    return {x = 0, y = 0, w = 1920, h = 1080}
                end
            }
        end
    },

    settings = {
        clear = function(key) settings[key] = nil end,
        get = function(key) return settings[key] end,
        set = function(key, value) settings[key] = value end
    },

    styledtext = {
        convertFont = function(font, bold)
            local converted = {}

            for key, value in pairs(font) do converted[key] = value end

            converted.bold = bold or nil
            return converted
        end,
        new = styledText,
        validFont = function() return true end
    },

    timer = {
        absoluteTime = function() return 0 end,
        doAfter = function(duration, callback)
            local timer = {duration = duration, callback = callback}

            function timer:stop() self.stopped = true end

            table.insert(createdTimers, timer)
            return timer
        end,
        doEvery = function() return {stop = function() end} end
    },

    webview = {
        new = function(frame, _, controller)
            return newWebview(frame, controller)
        end,
        usercontent = {
            new = function(name)
                local controller = {name = name}

                function controller:setCallback(callback)
                    self.callback = callback
                    return self
                end

                table.insert(createdWebviewControllers, controller)
                return controller
            end
        }
    }
}

local Actions = require("Spoons.Gearbox.actions")
local Loader = require("Spoons.Gearbox.loader")
local Theme = require("Spoons.Gearbox.theme")
local config = require("Spoons.Gearbox.config")

assert(config.menu.timeout == 0,
       "zero must remain the standalone disabled-timeout sentinel")
assert(config.loupe.selectedScale == 1.18 and config.loupe.duration == 0,
       "standalone loupe defaults must retain immediate navigation")
assert(config.scratchpad.enable and config.scratchpad.width == 720 and
           config.scratchpad.height == 480 and config.scratchpad.maxCharacters ==
           4096, "standalone scratchpad defaults changed")

local discoveredTheme = Theme.new(config, root .. "/Spoons/Gearbox")

local menus, rootId = Loader.load(root .. "/Spoons/Gearbox", config, Actions,
                                  {discoveredTheme:menuDefinition()},
                                  discoveredTheme)

assert(rootId == "leader", "leader must be the root menu")
assert(menus.leader.title == "Gearbox", "leader title changed")

local function rowShape(menu)
    local rows = {}

    for _, row in ipairs(menu.rows) do
        table.insert(rows, row.divider and "|" or row.key)
    end

    return table.concat(rows, ",")
end

local leaderShape = rowShape(menus.leader)

assert(leaderShape == "c,l,k,o,p,s,|,n,i,a,d,f,w,|,m,t,|,escape",
       "leader ordering or divider placement changed: " .. leaderShape)

local scratchpadRow

for _, row in ipairs(menus.leader.rows) do
    if row.action and row.action.type == "openScratchpad" then
        scratchpadRow = row
        break
    end
end

assert(scratchpadRow and scratchpadRow.key == "s" and scratchpadRow.requires ==
           nil,
       "declarative feature requirements must resolve before runtime assembly")

assert(rowShape(menus.browsers) == "o,a,c,s,|,escape",
       "browser menu shape changed")

assert(rowShape(menus.macos) == "h,e,|,a,i,x,|,s,|,escape",
       "macOS Utilities menu shape changed")

assert(rowShape(menus.themes) == "s,|,a,l,g,|,c,r,d,h,m,n,t,|,escape",
       "Themes menu shape changed")

local themeLabels = {}

for _, row in ipairs(menus.themes.rows) do
    if not row.divider then themeLabels[row.key] = row.label end
end

assert(themeLabels.l == "Gearbox Light", "light theme label changed")
assert(themeLabels.d == "Gearbox Dark", "dark theme label changed")
assert(menus.leader.rows[#menus.leader.rows].label:match("^Exit Gearbox"),
       "leader footer changed")

local themeCount = 0

for _ in pairs(discoveredTheme.themes) do themeCount = themeCount + 1 end

assert(themeCount == 10, "all bundled themes must be discovered")

local modalCountBeforeInvalidDefinitions = #createdModals

local missingFeatureRequirementAccepted = pcall(function()
    Loader.load(root .. "/Spoons/Gearbox", config, Actions, {
        discoveredTheme:menuDefinition(), {
            id = "requires-test",
            title = "Requires Test",
            parent = "leader",
            entry = {key = "q"},
            items = {
                {
                    key = "r",
                    label = "Missing Feature",
                    kind = "action",
                    requires = "missingFeature",
                    action = {type = "reload"}
                }
            }
        }
    }, discoveredTheme)
end)

assert(not missingFeatureRequirementAccepted,
       "unknown declarative feature requirements must fail early")

local missingThemeActionAccepted = pcall(function()
    Loader.load(root .. "/Spoons/Gearbox", config, Actions, {
        {
            id = "missing-theme-action",
            title = "Missing Theme Action",
            parent = "leader",
            entry = {key = "y", label = "Missing Theme Action"},
            items = {
                {
                    key = "q",
                    label = "Missing",
                    kind = "action",
                    action = {type = "setTheme", theme = "missing"}
                }
            }
        }
    }, discoveredTheme)
end)

assert(not missingThemeActionAccepted,
       "setTheme actions must reference a discovered theme")
assert(#createdModals == modalCountBeforeInvalidDefinitions,
       "action validation must finish before modals are allocated")

local duplicateChildAccepted = pcall(function()
    Loader.load(root .. "/Spoons/Gearbox", config, Actions, {
        {
            id = "duplicate-child-key",
            title = "Duplicate Child Key",
            parent = "leader",
            entry = {key = "c", label = "Duplicate Child Key"},
            items = {}
        }
    }, discoveredTheme)
end)

assert(not duplicateChildAccepted, "item and child keys must not collide")
assert(#createdModals == modalCountBeforeInvalidDefinitions,
       "menu assembly must finish before modals are allocated")

local modeActions = {}

for _, row in ipairs(menus.macos.rows) do
    if row.checkable then modeActions[row.key] = row.action end
end

local function checkedKey()
    local checked = {}
    local currentMode = Actions.currentCaffeinateMode()

    for key, action in pairs(modeActions) do
        if action.mode == currentMode then table.insert(checked, key) end
    end

    table.sort(checked)
    return table.concat(checked, ",")
end

local context = {exit = function() end, openMenu = function() end}

assert(checkedKey() == "x", "normal sleep must be checked by default")

Actions.execute(modeActions.a, context)
assert(checkedKey() == "a", "display mode must be the only checked mode")

Actions.execute(modeActions.i, context)
assert(checkedKey() == "i", "idle mode must be the only checked mode")

Actions.execute(modeActions.x, context)
assert(checkedKey() == "x", "normal mode must clear both assertions")

local reloadResult = Actions.execute({type = "reload"}, context)
assert(reloadCalls == 1, "reload action must reload Hammerspoon")
assert(reloadResult.handled == true,
       "reload action must stop runtime processing")

defaultTextStyleCalls = 0
interfaceStyleCalls = 0
osascriptCalls = 0
settings = {}

settings["Shift7.theme.selection"] = {
    selection = "shift7-dark",
    configuredDefault = "system"
}
settings["Gearbox.scratchpad.content"] = "restored draft"

local Gearbox = require("Spoons.Gearbox")
local expectedDisabledTimeoutMessage = table.concat({
    "╔═[ Gearbox configuration error ]" .. string.rep("═", 48) .. "╗",
    "║" .. string.rep(" ", 80) .. "║",
    "║  Gearbox cannot start because `menu.timeout` is set to `0` (disabled)." ..
        string.rep(" ", 9) .. "║",
    "║  Set `menu.timeout` to a positive number of seconds, then reload Hammerspoon." ..
        string.rep(" ", 2) .. "║",
    "║" .. string.rep(" ", 80) .. "║",
    "║  This window will be dismissed in 10 seconds." ..
        string.rep(" ", 34) .. "║",
    "║" .. string.rep(" ", 80) .. "║",
    "╚" .. string.rep("═", 80) .. "╝"
}, "\n")
local canvasesBeforeDisabledTimeout = #createdCanvases
local modalsBeforeDisabledTimeout = #createdModals
local timersBeforeDisabledTimeout = #createdTimers
local webviewsBeforeDisabledTimeout = #createdWebviews
local controllersBeforeDisabledTimeout = #createdWebviewControllers
local hotkeysBeforeDisabledTimeout = globalHotkeyBindCalls
local fontCallsBeforeDisabledTimeout = defaultTextStyleCalls
local appearanceCallsBeforeDisabledTimeout = interfaceStyleCalls
local accentCallsBeforeDisabledTimeout = osascriptCalls
local disabledTimeoutAccepted, disabledTimeoutError = pcall(function()
    Gearbox.start()
end)

assert(not disabledTimeoutAccepted,
       "the zero timeout sentinel must fail Gearbox startup")
assert(
    disabledTimeoutError == "Gearbox: menu.timeout must be greater than zero",
    "zero timeout must raise the dedicated configuration error")
assert(#shownAlerts == 1, "zero timeout must show one configuration alert")

local disabledTimeoutAlert = shownAlerts[1]
local disabledTimeoutStyle = disabledTimeoutAlert.style

assert(styledTextValue(disabledTimeoutAlert.message) ==
           expectedDisabledTimeoutMessage,
       "zero-timeout alert message changed")
assert(disabledTimeoutAlert.duration == 10,
       "zero-timeout alert must own a ten-second lifetime")
assert(disabledTimeoutStyle.textSize ==
           math.max(config.font.titleSize + 2, hs.alert.defaultStyle.textSize) and
           disabledTimeoutStyle.textSize > config.font.titleSize,
       "zero-timeout alert font must be larger than the menu header")
assert(disabledTimeoutStyle.fillColor.red == 0.72 and
           disabledTimeoutStyle.fillColor.green == 0 and
           disabledTimeoutStyle.fillColor.blue == 0 and
           disabledTimeoutStyle.fillColor.alpha == 0.98,
       "zero-timeout alert must use a red background")
assert(disabledTimeoutStyle.strokeWidth == 0,
       "the ASCII box must own the warning border")
assert(disabledTimeoutStyle.textColor.white == 1 and
           disabledTimeoutStyle.textColor.alpha == 1,
       "zero-timeout alert must use white text")
assert(disabledTimeoutStyle.radius == 0,
       "zero-timeout alert must use square corners")
assert(disabledTimeoutStyle.padding == disabledTimeoutStyle.textSize,
       "zero-timeout alert must have padding on every side")

local disabledTimeoutSegments = disabledTimeoutAlert.message.segments
local disabledTimeoutLegendSegment = disabledTimeoutSegments[2]

assert(#disabledTimeoutSegments == 3 and
           disabledTimeoutLegendSegment.text ==
           "This window will be dismissed in 10 seconds.",
       "zero-timeout alert must style the dismissal legend separately")
assert(disabledTimeoutLegendSegment.attributes.font.bold and
           disabledTimeoutLegendSegment.attributes.color.red == 1 and
           disabledTimeoutLegendSegment.attributes.color.green == 0.9 and
           disabledTimeoutLegendSegment.attributes.color.blue == 0,
       "zero-timeout dismissal legend must be bold yellow")
assert(disabledTimeoutSegments[1].attributes.color.white == 1 and
           disabledTimeoutSegments[3].attributes.color.white == 1 and
           not disabledTimeoutSegments[1].attributes.font.bold and
           not disabledTimeoutSegments[3].attributes.font.bold,
       "zero-timeout box characters must remain regular white")
assert(#createdCanvases == canvasesBeforeDisabledTimeout and #createdModals ==
           modalsBeforeDisabledTimeout and #createdTimers ==
           timersBeforeDisabledTimeout and #createdWebviews ==
           webviewsBeforeDisabledTimeout and #createdWebviewControllers ==
           controllersBeforeDisabledTimeout and globalHotkeyBindCalls ==
           hotkeysBeforeDisabledTimeout and defaultTextStyleCalls ==
           fontCallsBeforeDisabledTimeout and interfaceStyleCalls ==
           appearanceCallsBeforeDisabledTimeout and osascriptCalls ==
           accentCallsBeforeDisabledTimeout,
       "zero timeout must fail before allocating the Gearbox runtime")

local configModule = "Spoons.Gearbox.config"

local function copyFixture(value)
    if type(value) ~= "table" then return value end

    local result = {}

    for key, item in pairs(value) do result[key] = copyFixture(item) end

    return result
end

local function applyFixture(target, values)
    for key, value in pairs(values or {}) do
        if type(value) == "table" and type(target[key]) == "table" and
            value[1] == nil and target[key][1] == nil then
            applyFixture(target[key], value)
        else
            target[key] = copyFixture(value)
        end
    end
end

local function startGearbox(values)
    local fixture = dofile(root .. "/Spoons/Gearbox/config.lua")
    applyFixture(fixture, values)
    package.loaded[configModule] = fixture
    return Gearbox.start()
end

local overridesAccepted, overridesError = pcall(function()
    Gearbox.start({})
end)

assert(not overridesAccepted and overridesError ==
           "Gearbox: edit Spoons/Gearbox/config.lua instead of passing overrides",
       "Gearbox.start must reject external configuration overrides")

local runtime = startGearbox({
    menu = {timeout = 5},
    theme = {
        accentSource = "theme",
        overrides = {
            ["gearbox-dark"] = {
                accent = {white = 0.5},
                background = {red = 0.05, green = 0.06, blue = 0.07}
            }
        }
    }
})

assert(settings["Shift7.theme.selection"] == nil,
       "legacy persistence key must be cleared after activation")
assert(settings["Gearbox.theme.selection"].selection == "gearbox-dark" and
           settings["Gearbox.theme.selection"].configuredDefault == "system",
       "legacy persistence must migrate built-in theme IDs")

assert(type(globalHotkeyPressed) == "function",
       "global hotkey was not registered")
assert(interfaceStyleCalls == 0,
       "system appearance must remain lazy until a menu opens")

globalHotkeyPressed()
assert(runtime.activeMenu.id == "leader", "global hotkey must open leader")
assert(runtime.timeoutTimer and runtime.timeoutTimer.duration == 5,
       "a positive timeout must arm the menu timer")
assert(interfaceStyleCalls == 0,
       "a migrated manual theme must not resolve system appearance")

assert(runtime.hud.theme.colors.background.white == nil and
           runtime.hud.theme.colors.background.red == 0.05,
       "RGB overrides must replace a grayscale color model")

assert(runtime.hud.theme.colors.background.alpha == 0.96,
       "color-model replacement must retain the default alpha")

assert(runtime.hud.theme.colors.selection.white == 0.5 and
           runtime.hud.theme.colors.selection.red == nil and
           runtime.hud.theme.colors.selection.alpha == 0.22,
       "selection colors must preserve grayscale accent overrides")

assert(runtime.theme.activeThemeId == "gearbox-dark",
       "migrated dark selection must resolve the Gearbox dark theme")
assert(runtime.scratchpad.content == "restored draft",
       "scratchpad must restore persisted content")
assert(#createdWebviews == 1 and not createdWebviews[1].visible,
       "scratchpad webview must be prewarmed before its first invocation")
assert(runtime.hud.canvas.elements[1].roundedRectRadii.xRadius ==
           runtime.theme.metrics.windowCornerRadius,
       "menu HUD and scratchpad must share the outer corner radius")

assert(defaultTextStyleCalls == 1,
       "system font defaults must be resolved once per theme")

assert(osascriptCalls == 0, "theme accents must not resolve the system accent")

local function findBinding(modal, key, modifiers)
    local expectedModifiers = table.concat(modifiers, "+")

    for _, binding in ipairs(modal.bindingCalls) do
        if binding.key == key and table.concat(binding.modifiers, "+") ==
            expectedModifiers then return binding end
    end
end

local rootModal = runtime.menus.leader.modal

assert(findBinding(rootModal, "d", config.hotkey.modifiers),
       "item keys must accept the retained leader modifiers")

assert(not findBinding(rootModal, "escape", config.hotkey.modifiers),
       "Escape must not shadow the native modified shortcut")

assert(not findBinding(rootModal, "down", config.hotkey.modifiers),
       "navigation arrows must not shadow modified system shortcuts")

assert(not findBinding(rootModal, "return", config.hotkey.modifiers),
       "Return activation must be bound without leader modifiers")

local downBinding = assert(findBinding(rootModal, "down", {}))

assert(downBinding.pressed and downBinding.repeated,
       "arrow navigation must run on key press and key repeat")

local menuEntryTimer = runtime.timeoutTimer

runtime.menus.leader.modal.bindings.down()
assert(runtime.menus.leader.selectedIndex == 1,
       "first Down press must select the first entry")
assert(menuEntryTimer.stopped and runtime.timeoutTimer ~= menuEntryTimer and
           runtime.timeoutTimer.duration == 5,
       "navigation input must reset a positive timeout")

runtime.timeoutTimer.callback()
assert(runtime.activeMenu == nil and runtime.timeoutTimer == nil,
       "an elapsed positive timeout must exit the active modal")
assert(#shownAlerts == 1,
       "an elapsed positive timeout must not show a dismissal message")

globalHotkeyPressed()
runtime.menus.leader.modal.bindings.down()
runtime.menus.leader.modal.bindings["return"]()
assert(launchedApplication == "Calculator",
       "Return must activate selected entry")
assert(runtime.activeMenu == nil, "application launch must close Gearbox")

globalHotkeyPressed()
runtime.menus.leader.modal.bindings.s()

assert(runtime.activeMenu == nil, "scratchpad must replace the menu HUD")
assert(#createdWebviews == 1, "scratchpad must reuse its prewarmed webview")
assert(createdWebviewControllers[1].name == "gearboxScratchpad",
       "scratchpad must use its private message bridge")
assert(createdWebviews[1].visible, "scratchpad action must show the webview")
assert(createdWebviews[1].allowTextEntryValue == true and
           createdWebviews[1].transparentValue == true and
           createdWebviews[1].shadowValue == true and
           #createdWebviews[1].windowStyleValue == 0,
       "scratchpad must be an editable, transparent, borderless panel")
assert(createdWebviews[1].currentFrame.w == 720 and
           createdWebviews[1].currentFrame.h == 480 and
           createdWebviews[1].currentFrame.x == 600 and
           createdWebviews[1].currentFrame.y == 150,
       "scratchpad must use configured size and Gearbox placement")
assert(createdWebviews[1].document:match("Tab inserts tabs"),
       "scratchpad must include the non-editable instructions")
assert(not createdWebviews[1].document:match('event.key === "Escape"'),
       "scratchpad must not bind Escape")

local scratchpadState = runtime.scratchpad:state(false)

assert(scratchpadState.instructions ==
           "Cursor keys move · Tab inserts tabs · alt+cmd+space closes scratchpad",
       "scratchpad instructions must include the configured Gearbox hotkey")
assert(scratchpadState.footerSize == 13,
       "scratchpad instructions must remain subtle but legible")
assert(scratchpadState.maxCharacters == 4096 and
           createdWebviews[1].document:match(
               "editor.maxLength = state.maxCharacters"),
       "scratchpad must expose its configured capacity to the native editor")

createdWebviewControllers[1].callback({
    action = "save",
    content = "persistent draft"
})

assert(settings["Gearbox.scratchpad.content"] == "persistent draft",
       "scratchpad content must persist through hs.settings")

createdWebviews[1].contentResult = "persistent draft"
globalHotkeyPressed()
assert(not createdWebviews[1].visible,
       "global Gearbox hotkey must hide the scratchpad")

globalHotkeyPressed()
runtime.menus.leader.modal.bindings.s()
assert(#createdWebviews == 1 and createdWebviews[1].visible,
       "scratchpad must reuse its existing webview")

createdWebviews[1].contentResult = "reopened draft"
globalHotkeyPressed()

assert(
    not createdWebviews[1].visible and settings["Gearbox.scratchpad.content"] ==
        "reopened draft",
    "Gearbox hotkey must save and hide the reopened scratchpad")

globalHotkeyPressed()
runtime.menus.leader.modal.bindings.m()
assert(runtime.activeMenu.id == "macos", "m must open macOS Utilities")

local styleCallsBeforeHUDRefresh = interfaceStyleCalls

runtime.menus.macos.modal.bindings.a()
assert(Actions.currentCaffeinateMode() == "display",
       "display mode action must remain active after HUD refresh")
assert(runtime.activeMenu.id == "macos",
       "changing a power mode must keep macOS Utilities open")
assert(interfaceStyleCalls == styleCallsBeforeHUDRefresh,
       "HUD-only refreshes must not resolve system appearance")

runtime.menus.macos.modal.bindings.escape()
runtime.menus.leader.modal.bindings.t()
assert(runtime.activeMenu.id == "themes", "t must open Themes")

local function checkedThemeKeys()
    local checked = runtime:checkedRows(runtime.menus.themes)
    local keys = {}

    for index, row in ipairs(runtime.menus.themes.rows) do
        if checked[index] then table.insert(keys, row.key) end
    end

    return table.concat(keys, ",")
end

assert(checkedThemeKeys() == "d",
       "migrated theme must be the only checked selector")

local styleCallsBeforeThemePreview = interfaceStyleCalls

runtime.menus.themes.modal.bindings.c()

assert(runtime.theme.selection == "catppuccin-mocha",
       "theme action must update the selected theme")
assert(runtime.theme.activeThemeId == "catppuccin-mocha",
       "theme action must immediately apply its palette")
assert(runtime.theme.colors.accent.red == 0.796078,
       "theme accent source must use the selected preset")
assert(interfaceStyleCalls == styleCallsBeforeThemePreview,
       "manual theme previews must not resolve system appearance")
assert(checkedThemeKeys() == "c", "only the selected theme must be checked")
assert(settings["Gearbox.theme.selection"].selection == "catppuccin-mocha",
       "theme selections must persist")

interfaceStyle = nil
runtime.menus.themes.modal.bindings.s()

assert(runtime.theme.selection == "system", "system selection must be restored")
assert(runtime.theme.activeThemeId == "gearbox-light",
       "system selection must resolve the light appearance")
assert(checkedThemeKeys() == "s", "system must regain the exclusive check")

interfaceStyle = "Dark"
runtime.menus.themes.modal.bindings.escape()

assert(runtime.theme.activeThemeId == "gearbox-dark",
       "modal entry must re-evaluate the system appearance")

runtime.menus.leader.modal.bindings.t()
runtime.menus.themes.modal.bindings.r()

assert(runtime.theme.selection == "dracula",
       "manual selection must switch away from system mode")

local validRuntime = runtime
local alertsBeforeFailedReplacement = #shownAlerts
local canvasesBeforeFailedReplacement = #createdCanvases
local modalsBeforeFailedReplacement = #createdModals
local timersBeforeFailedReplacement = #createdTimers
local webviewsBeforeFailedReplacement = #createdWebviews
local controllersBeforeFailedReplacement = #createdWebviewControllers
local hotkeysBeforeFailedReplacement = globalHotkeyBindCalls
local fontCallsBeforeFailedReplacement = defaultTextStyleCalls
local failedReplacementAccepted, failedReplacementError = pcall(function()
    startGearbox({menu = {timeout = 0}})
end)

assert(not failedReplacementAccepted and failedReplacementError ==
           "Gearbox: menu.timeout must be greater than zero",
       "zero-timeout replacement must fail with the dedicated error")
assert(#shownAlerts == alertsBeforeFailedReplacement + 1 and
           styledTextValue(shownAlerts[#shownAlerts].message) ==
           expectedDisabledTimeoutMessage and
           shownAlerts[#shownAlerts].duration == 10,
       "zero-timeout replacement must show the configuration alert")
assert(
    #createdCanvases == canvasesBeforeFailedReplacement and #createdModals ==
        modalsBeforeFailedReplacement and #createdTimers ==
        timersBeforeFailedReplacement and #createdWebviews ==
        webviewsBeforeFailedReplacement and #createdWebviewControllers ==
        controllersBeforeFailedReplacement and globalHotkeyBindCalls ==
        hotkeysBeforeFailedReplacement and defaultTextStyleCalls ==
        fontCallsBeforeFailedReplacement,
    "zero-timeout replacement must not allocate a candidate runtime")
assert(validRuntime.started and validRuntime.activeMenu.id == "themes",
       "zero-timeout replacement must preserve the active runtime")

local mixedColorAccepted = pcall(function()
    startGearbox({
        menu = {timeout = 5},
        theme = {
            overrides = {
                dracula = {
                    background = {
                        white = 0.1,
                        red = 0.1,
                        green = 0.1,
                        blue = 0.1
                    }
                }
            }
        }
    })
end)

assert(not mixedColorAccepted, "mixed grayscale and RGB colors must fail")
assert(validRuntime.started,
       "invalid overrides must not stop the active runtime")
assert(validRuntime.activeMenu.id == "themes",
       "invalid overrides must preserve the active menu")

local unknownThemeAccepted = pcall(function()
    startGearbox({
        menu = {timeout = 5},
        theme = {overrides = {missing = {selectionAlpha = 0.2}}}
    })
end)

assert(not unknownThemeAccepted, "unknown theme overrides must fail")
assert(validRuntime.started, "unknown overrides must preserve active runtime")

local unknownFieldAccepted = pcall(function()
    startGearbox({
        menu = {timeout = 5},
        theme = {overrides = {dracula = {unknown = 1}}}
    })
end)

assert(not unknownFieldAccepted, "unknown theme override fields must fail")
assert(validRuntime.started, "unknown fields must preserve active runtime")

local invalidKeyAccepted = pcall(function()
    startGearbox({hotkey = {key = "not-a-real-key"}, menu = {timeout = 5}})
end)

assert(not invalidKeyAccepted, "invalid Hammerspoon keys must fail early")
assert(validRuntime.started, "invalid keys must not stop the active runtime")
assert(validRuntime.activeMenu.id == "themes",
       "invalid keys must preserve the active menu")

local reservedCaseAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, navigation = {activateKey = "Down"}})
end)

assert(not reservedCaseAccepted,
       "reserved navigation keys must be compared case-insensitively")
assert(validRuntime.activeMenu.id == "themes",
       "reserved key failures must preserve the active menu")

local smallScratchpadAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, scratchpad = {width = 359}})
end)

assert(not smallScratchpadAccepted,
       "undersized scratchpad dimensions must fail early")
assert(validRuntime.activeMenu.id == "themes",
       "scratchpad validation failures must preserve the active menu")

local invalidScratchpadCapacityAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, scratchpad = {maxCharacters = 0}})
end)

assert(not invalidScratchpadCapacityAccepted,
       "scratchpad capacity must be a positive integer")
assert(validRuntime.activeMenu.id == "themes",
       "scratchpad capacity failures must preserve the active menu")

local fontCallsBeforePartialStart = defaultTextStyleCalls
local partialStartModalIndex = #createdModals + 1
failNextModalBind = true

local partialStartAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, theme = {accentSource = "theme"}})
end)

assert(not partialStartAccepted, "partial modal registration must fail startup")

for index = partialStartModalIndex, #createdModals do
    assert(createdModals[index].deleted,
           "partial startup must delete every candidate modal")
end

assert(validRuntime.started, "partial startup must preserve the active runtime")
assert(defaultTextStyleCalls == fontCallsBeforePartialStart + 1,
       "a failed candidate must resolve fonts only once")
assert(validRuntime.activeMenu.id == "themes",
       "partial startup must preserve the active menu")

local fontCallsBeforeGlobalFailure = defaultTextStyleCalls
local globalFailureModalIndex = #createdModals + 1
failNextGlobalHotkey = true

local unavailableHotkeyAccepted = pcall(function()
    startGearbox({
        menu = {timeout = 5},
        theme = {name = "gearbox-light", accentSource = "theme"}
    })
end)

assert(not unavailableHotkeyAccepted,
       "unavailable global hotkeys must fail startup")
assert(validRuntime.started,
       "failed hotkey registration must not stop the active runtime")
assert(validRuntime.activeMenu.id == "themes",
       "failed hotkey registration must preserve the active menu")
assert(defaultTextStyleCalls == fontCallsBeforeGlobalFailure + 1,
       "an unavailable hotkey candidate must resolve fonts only once")

for index = globalFailureModalIndex, #createdModals do
    assert(createdModals[index].deleted,
           "failed hotkey registration must delete every candidate modal")
end

assert(settings["Gearbox.theme.selection"].selection == "dracula" and
           settings["Gearbox.theme.selection"].configuredDefault == "system",
       "failed replacement must not clear the active persisted selection")

local fontCallsBeforeReplacements = defaultTextStyleCalls

local replacementRuntime = startGearbox({
    menu = {timeout = 5},
    theme = {accentSource = "theme"}
})

assert(replacementRuntime.started, "replacement runtime must start")
assert(replacementRuntime.theme.selection == "dracula",
       "a valid persisted selection must survive reload")
assert(not validRuntime.started,
       "successful replacement must stop the previous runtime")

local configuredRuntime = startGearbox({
    menu = {timeout = 5},
    theme = {name = "gearbox-light", accentSource = "theme"}
})

assert(configuredRuntime.theme.selection == "gearbox-light",
       "a changed configured default must invalidate persisted selection")
assert(settings["Gearbox.theme.selection"] == nil,
       "invalidated persisted selection must be cleared")

settings["Gearbox.theme.selection"] = {
    selection = "removed-theme",
    configuredDefault = "gearbox-light"
}

local missingThemeRuntime = startGearbox({
    menu = {timeout = 5},
    theme = {name = "gearbox-light", accentSource = "theme"}
})

assert(missingThemeRuntime.theme.selection == "gearbox-light",
       "a missing persisted theme must fall back to configuration")
assert(settings["Gearbox.theme.selection"] == nil,
       "a missing persisted theme must be cleared")

settings["Gearbox.theme.selection"] = {
    selection = "dracula",
    configuredDefault = "gearbox-light"
}

local nonPersistentRuntime = startGearbox({
    menu = {timeout = 5},
    theme = {
        name = "gearbox-light",
        persistSelection = false,
        accentSource = "theme"
    }
})

assert(nonPersistentRuntime.theme.selection == "gearbox-light",
       "disabled persistence must use configured selection")
assert(settings["Gearbox.theme.selection"] == nil,
       "disabled persistence must clear stored selection")

assert(defaultTextStyleCalls == fontCallsBeforeReplacements + 4,
       "each replacement must resolve fonts once and modal refreshes never should")

local accentCallsBefore = osascriptCalls
local systemAccentRuntime = startGearbox({
    menu = {timeout = 5},
    theme = {
        name = "gearbox-dark",
        persistSelection = false,
        accentSource = "system"
    }
})

assert(osascriptCalls == accentCallsBefore + 1,
       "system accent must resolve once during startup")

globalHotkeyPressed()

assert(systemAccentRuntime.theme.colors.accent.red == 0.2,
       "system accent source must use the resolved macOS accent")

local noScratchpadRuntime = startGearbox({
    menu = {timeout = 5},
    scratchpad = {enable = false},
    theme = {accentSource = "theme"}
})

assert(noScratchpadRuntime.menus.leader.modal.bindings.s == nil,
       "disabled scratchpad must not register a root-menu key")

Gearbox.stop()

print("Gearbox smoke test passed")
