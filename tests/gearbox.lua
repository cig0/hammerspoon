local root = assert(arg[1], "repository root argument is required")

package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local caffeinateState = {displayIdle = false, systemIdle = false}

local createdCanvases = {}
local createdEventTaps = {}
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
local failNextEventTapStart = false
local failNextWebviewSetup = false
local polledCapsLockEnabled = false
local capsLockRenderState = {enabled = false, reads = 0}
local secureInputEnabled = false
local interfaceStyle = "Dark"
local interfaceStyleCalls = 0
local osascriptCalls = 0
local reloadCalls = 0
local settings = {}
local mouseButtons = {}
local fileModes = {}
local jsonFiles = {}
local chosenPaths = {}
local promptResponses = {}
local homeDirectory = assert(os.getenv("HOME"))
local preferencesPath = homeDirectory ..
                            "/.config/hammerspoon-gearbox/preferences.json"

local keycodesByName = {
    a = 0,
    b = 11,
    c = 8,
    d = 2,
    e = 14,
    f = 3,
    g = 5,
    h = 4,
    i = 34,
    j = 38,
    k = 40,
    l = 37,
    m = 46,
    n = 45,
    o = 31,
    p = 35,
    q = 12,
    r = 15,
    s = 1,
    t = 17,
    u = 32,
    v = 9,
    w = 13,
    x = 7,
    y = 16,
    z = 6,
    ["0"] = 29,
    ["1"] = 18,
    ["2"] = 19,
    ["3"] = 20,
    ["4"] = 21,
    ["5"] = 23,
    ["6"] = 22,
    ["7"] = 26,
    ["8"] = 28,
    ["9"] = 25,
    down = 125,
    escape = 53,
    ["return"] = 36,
    space = 49,
    tab = 48,
    up = 126
}

local keycodeMap = {}

for key, keycode in pairs(keycodesByName) do
    keycodeMap[key] = keycode
    keycodeMap[keycode] = key
end

fileModes["/"] = "directory"
fileModes[homeDirectory] = "directory"

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

local function newCanvas(frame)
    local canvas = {elements = {}, currentFrame = frame}

    function canvas:appendElements(elements)
        self.elements = elements
        return self
    end

    function canvas:replaceElements(elements)
        self.elements = elements
        return self
    end

    function canvas:elementAttribute(index, attribute, value)
        self.elements[index][attribute] = value
        return self
    end

    function canvas:wantsLayer() return self end

    function canvas:level(value)
        self.levelValue = value
        return self
    end

    function canvas:clickActivating(value)
        self.clickActivatingValue = value
        return self
    end

    function canvas:mouseCallback(callback)
        self.mouseCallbackValue = callback
        return self
    end

    function canvas:canvasMouseEvents() return self end

    function canvas:show()
        self.visible = true
        return self
    end

    function canvas:delete() self.visible = false end

    table.insert(createdCanvases, canvas)
    return canvas
end

local function newEventTap(callback)
    local eventTap = {callback = callback, enabled = false}

    function eventTap:start()
        if failNextEventTapStart then
            failNextEventTapStart = false
            self.enabled = false
        else
            self.enabled = true
        end

        return self
    end

    function eventTap:stop()
        self.enabled = false
        return self
    end

    function eventTap:isEnabled() return self.enabled end

    table.insert(createdEventTaps, eventTap)
    return eventTap
end

local function elementById(canvas, id)
    for _, element in ipairs(canvas.elements) do
        if element.id == id then return element end
    end
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
            if name == "windowStyle" and failNextWebviewSetup then
                failNextWebviewSetup = false
                error("simulated webview setup failure")
            end

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
        show = function(message, style, screen, duration)
            table.insert(shownAlerts, {
                message = message,
                style = style,
                screen = screen,
                duration = duration
            })
        end
    },

    application = {
        launchOrFocus = function(name) launchedApplication = name end
    },

    canvas = {
        windowLevels = {desktopIcon = 10, floating = 20},
        defaultTextStyle = function()
            defaultTextStyleCalls = defaultTextStyleCalls + 1

            return {font = {name = "System", size = 14}}
        end,
        new = function(frame) return newCanvas(frame) end
    },

    caffeinate = {
        get = function(kind) return caffeinateState[kind] end,
        set = function(kind, value) caffeinateState[kind] = value end,
        systemSleep = function() end
    },

    dialog = {
        chooseFileOrFolder = function()
            return table.remove(chosenPaths, 1)
        end,
        textPrompt = function()
            local response = table.remove(promptResponses, 1)
            return response and response.button or "Cancel",
                   response and response.text or ""
        end
    },

    eventtap = {
        checkKeyboardModifiers = function()
            return {capslock = polledCapsLockEnabled}
        end,
        checkMouseButtons = function() return mouseButtons end,
        event = {
            properties = {keyboardEventAutorepeat = 8},
            rawFlagMasks = {alphaShift = 0x00010000},
            types = {keyDown = 10}
        },
        isSecureInputEnabled = function() return secureInputEnabled end,
        new = function(_, callback) return newEventTap(callback) end
    },

    fs = {
        attributes = function(path, name)
            local mode = fileModes[path]

            if mode == nil and jsonFiles[path] ~= nil then mode = "file" end

            if name == "mode" then return mode end

            return mode and {mode = mode} or nil, "missing: " .. path
        end,
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
        end,
        mkdir = function(path)
            fileModes[path] = "directory"
            return true
        end,
        symlinkAttributes = function(path, name)
            local mode = fileModes[path] == "link" and "link" or nil

            if name == "mode" then return mode end

            return mode and {mode = mode} or nil, "missing: " .. path
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

    hid = {
        capslock = {
            get = function()
                capsLockRenderState.reads = capsLockRenderState.reads + 1
                return capsLockRenderState.enabled
            end
        }
    },

    json = {
        decode = function(value)
            if value == "system-accent" then
                return {red = 0.2, green = 0.3, blue = 0.4, alpha = 1}
            end

            return nil
        end,
        encode = function() return "{}" end,
        read = function(path) return jsonFiles[path] end,
        write = function(value, path)
            jsonFiles[path] = value
            fileModes[path] = "file"
            return true
        end
    },

    keycodes = {map = keycodeMap},

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
        fontInfo = function()
            return {
                fixedPitch = true,
                maximumAdvancement = {w = 11},
                ascender = 14,
                descender = -4,
                leading = 2
            }
        end,
        new = styledText,
        validFont = function() return true end
    },

    timer = {
        absoluteTime = function() return 0 end,
        doAfter = function(duration, callback)
            local timer = {duration = duration, callback = callback}

            function timer:stop() self.stopped = true end

            function timer:fire()
                if not self.stopped and not self.fired then
                    self.fired = true
                    self.callback()
                end
            end

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
local Preferences = require("Spoons.Gearbox.preferences")
local ScratchpadStorage = require("Spoons.Gearbox.scratchpad_storage")
local Theme = require("Spoons.Gearbox.theme")
local Validation = require("Spoons.Gearbox.validation")
local config = require("Spoons.Gearbox.config")

assert(config.menu.timeout == 0,
       "zero must remain the standalone disabled-timeout sentinel")
assert(config.menu.position == "top",
       "top must remain the standalone menu-position default")
assert(config.loupe.selectedScale == 1.18 and config.loupe.duration == 0,
       "standalone loupe defaults must retain immediate navigation")
assert(config.scratchpad.enable and config.scratchpad.width == 720 and
           config.scratchpad.height == 480 and config.scratchpad.maxCharacters ==
           4096 and config.scratchpad.fontSize == 14 and
           config.scratchpad.storagePath == nil,
       "standalone scratchpad defaults changed")

for byte = 0x21, 0x7e do
    assert(Validation.isCharacterActivationKey(string.char(byte)),
           "all printable non-space ASCII characters must be valid menu keys")
end

assert(Validation.hotkeyIdentity("Down") == "down" and
           Validation.hotkeyIdentity("#01") == "#1" and
           Validation.menuActivationIdentity("w") == "w" and
           Validation.menuActivationIdentity("W") == "W" and
           Validation.isCharacterActivationKey("!") and
           not Validation.isCharacterActivationKey(" ") and
           not Validation.isCharacterActivationKey(string.char(0x7f)) and
           Validation.isMenuActivationKey("!") and
           not Validation.isMenuActivationKey("#13") and
           not Validation.isMenuActivationKey("pad1") and
           not Validation.isHotkeyKey("!") and
           Validation.isMenuNavigationKey("q") and
           not Validation.isMenuNavigationKey("#13") and
           not Validation.isMenuNavigationKey("pad1") and
           Validation.isHotkeyKey("#13") and
           Validation.isHotkeyKey("space") and
           not Validation.isHotkeyKey("not-a-real-key"),
       "menu and modal key validation must preserve separate semantics")

local ambiguousNavigationAccepted = pcall(function()
    local invalidConfig = dofile(root .. "/Spoons/Gearbox/config.lua")
    invalidConfig.navigation.cancelKey = "pad1"
    Validation.validateConfig(invalidConfig)
end)

assert(not ambiguousNavigationAccepted,
       "printable keypad navigation must not compete with character rows")

local configColorAccepted, configColorError = pcall(function()
    Validation.validateColor({
        red = 2,
        green = 0,
        blue = 0,
        alpha = 1
    }, "theme.fallbackAccent", {configMessages = true})
end)

assert(not configColorAccepted and
           tostring(configColorError):match(
               "theme%.fallbackAccent%.red must be 0%.%.1$"),
       "config color validation diagnostics must remain compatible")

local relativeStorageAccepted = pcall(function()
    local invalidConfig = dofile(root .. "/Spoons/Gearbox/config.lua")
    invalidConfig.scratchpad.storagePath = "relative/scratchpad.txt"
    Validation.validateConfig(invalidConfig)
end)

assert(not relativeStorageAccepted,
       "relative scratchpad storage paths must fail configuration validation")

local themeColorAccepted, themeColorError = pcall(function()
    Validation.validateColor({
        red = 2,
        green = 0,
        blue = 0,
        alpha = 1
    }, "theme.overrides.dracula.background")
end)

assert(not themeColorAccepted and
           tostring(themeColorError):match(
               "Gearbox: theme%.overrides%.dracula%.background%.red must be a number from 0 to 1$"),
       "theme color validation diagnostics must remain compatible")

local discoveredTheme = Theme.new(config, root .. "/Spoons/Gearbox")
local discoveredPreferences = Preferences.new(config)
local supplementalMenus = {discoveredTheme:menuDefinition()}

for _, definition in ipairs(discoveredPreferences:menuDefinitions()) do
    table.insert(supplementalMenus, definition)
end

local menus, rootId = Loader.load(root .. "/Spoons/Gearbox", config, Actions,
                                  supplementalMenus, discoveredTheme)

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

assert(leaderShape == "C,L,K,O,P,s,|,n,i,a,d,f,w,|,m,g,|,escape",
       "leader ordering or divider placement changed: " .. leaderShape)

for _, menu in pairs(menus) do
    for _, row in ipairs(menu.rows) do
        if row.action and row.action.type == "launchApp" then
            assert(row.key:match("^[A-Z]$"),
                   "bundled application shortcuts must be uppercase: " ..
                       row.label)
        end
    end
end

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

assert(rowShape(menus.browsers) == "O,A,C,F,S,|,escape",
       "browser menu shape changed")

assert(menus.browsers.rows[4].action.name == "Firefox",
       "Firefox must launch Firefox")

assert(rowShape(menus.macos) == "E,|,a,i,x,|,s,|,escape",
       "macOS Utilities menu shape changed")
assert(rowShape(menus.applications) == "c,o,p,|,escape",
       "nested Applications group ordering changed")
assert(menus.leader.activationRowsByCharacter.C.label == "Calculator" and
           menus.leader.activationRowsByCharacter.a.label == "Applications" and
           menus.leader.activationRowsByCharacter.escape == nil,
       "loader must precompute exact character rows without the footer")
assert(menus.applications.activationRowsByCharacter.c.label == "Communications",
       "nested group rows must enter the character lookup")

local characterDefinitions = {}

for _, definition in ipairs(supplementalMenus) do
    table.insert(characterDefinitions, definition)
end

table.insert(characterDefinitions, {
    id = "character-test",
    title = "Character Test",
    parent = "leader",
    entry = {key = "W", label = "Uppercase Character"},
    items = {
        {
            key = "1",
            label = "Digit",
            kind = "action",
            action = {type = "reload"}
        }, {
            key = "!",
            label = "Shifted Symbol",
            kind = "action",
            action = {type = "reload"}
        }
    }
})

local characterMenus = Loader.load(root .. "/Spoons/Gearbox", config, Actions,
                                   characterDefinitions, discoveredTheme)

assert(characterMenus.leader.activationRowsByCharacter.w and
           characterMenus.leader.activationRowsByCharacter.W,
       "lowercase and uppercase character rows must coexist")
assert(characterMenus["character-test"].activationRowsByCharacter["1"] and
           characterMenus["character-test"].activationRowsByCharacter["!"],
       "digits and shifted symbols must coexist")

local uppercaseNavigationConfig = dofile(root .. "/Spoons/Gearbox/config.lua")
uppercaseNavigationConfig.navigation.cancelKey = "W"

local uppercaseNavigationAccepted = pcall(function()
    Loader.load(root .. "/Spoons/Gearbox", uppercaseNavigationConfig, Actions,
                supplementalMenus, discoveredTheme)
end)

assert(not uppercaseNavigationAccepted,
       "a modal-owned letter must reserve both Caps Lock cases")

local printableFooterConfig = dofile(root .. "/Spoons/Gearbox/config.lua")
printableFooterConfig.navigation.cancelKey = "q"

local printableFooterMenus = Loader.load(root .. "/Spoons/Gearbox",
                                         printableFooterConfig, Actions,
                                         supplementalMenus, discoveredTheme)
local printableFooter = printableFooterMenus.leader.rows[
                            #printableFooterMenus.leader.rows]

assert(printableFooter.kind == "footer" and printableFooter.key == "q" and
           printableFooterMenus.leader.activationRowsByCharacter.q == nil,
       "printable footer keys must remain exclusively modal-owned")

local rawMenuKeyAccepted = pcall(function()
    Loader.load(root .. "/Spoons/Gearbox", config, Actions, {
        {
            id = "raw-key-child",
            title = "Raw Key Child",
            parent = "leader",
            entry = {key = "#13", label = "Raw Key Child"}
        }
    }, discoveredTheme)
end)

assert(not rawMenuKeyAccepted,
       "raw menu keys must not overlap resulting-character ownership")

assert(not pcall(function()
    Loader.load(root .. "/Spoons/Gearbox", config, Actions, {
        {
            id = "invalid-footer-divider",
            title = "Invalid Footer Divider",
            parent = "leader",
            showFooterDivider = "no",
            entry = {key = "v", label = "Invalid Footer Divider"}
        }
    }, discoveredTheme)
end), "showFooterDivider must remain explicit Boolean menu data")

assert(not pcall(function()
    Loader.load(root .. "/Spoons/Gearbox", config, Actions, {
        {
            id = "invalid-legend",
            title = "Invalid Legend",
            parent = "leader",
            legend = "",
            entry = {key = "v", label = "Invalid Legend"}
        }
    }, discoveredTheme)
end), "passive menu legends must be non-empty strings")

assert(rowShape(menus.themes) == "s,|,a,l,g,|,c,r,d,h,m,n,t,|,escape",
       "Themes menu shape changed")
assert(rowShape(menus.configuration) == "h,|,p,r,x,|,m,s,t,|,escape",
       "Gearbox Configuration menu shape changed")
assert(menus.configuration.title == "Gearbox Configuration" and
           menus.themes.parentId == "configuration",
       "Themes must belong to Gearbox Configuration")
assert(menus.configuration.legend ==
           "Trigger: ⌥⌘Space · Customizable via Spoon docs",
       "configuration legend must derive the configured Gearbox trigger")
assert(rowShape(menus["menu-position"]) == "t,b,|,escape",
       "Menu Position menu shape changed")
assert(rowShape(menus["scratchpad-settings"]) ==
           "p,h,f,n,|,w,e,|,escape", "Scratchpad settings menu shape changed")

local themeLabels = {}

for _, row in ipairs(menus.themes.rows) do
    if not row.divider then themeLabels[row.key] = row.label end
end

assert(themeLabels.l == "Gearbox Light", "light theme label changed")
assert(themeLabels.d == "Gearbox Dark", "dark theme label changed")
assert(menus.leader.rows[#menus.leader.rows].label:match("^Exit Gearbox"),
       "leader footer changed")

assert(menus.macos.rows[#menus.macos.rows].label == "Back to main menu",
       "root child footers must point back to the main menu")

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
            entry = {key = "C", label = "Duplicate Child Key"},
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
local canvasesBeforeDisabledTimeout = #createdCanvases
local modalsBeforeDisabledTimeout = #createdModals
local timersBeforeDisabledTimeout = #createdTimers
local webviewsBeforeDisabledTimeout = #createdWebviews
local controllersBeforeDisabledTimeout = #createdWebviewControllers
local hotkeysBeforeDisabledTimeout = globalHotkeyBindCalls
local fontCallsBeforeDisabledTimeout = defaultTextStyleCalls
local appearanceCallsBeforeDisabledTimeout = interfaceStyleCalls
local accentCallsBeforeDisabledTimeout = osascriptCalls
local disabledTimeoutAccepted, disabledTimeoutResult = pcall(function()
    Gearbox.start()
end)

assert(disabledTimeoutAccepted and disabledTimeoutResult == nil,
       "the zero timeout sentinel must show its warning without failing Hammerspoon setup")
local disabledTimeoutCanvas = createdCanvases[#createdCanvases]
local disabledTimeoutModal = createdModals[#createdModals]
local disabledTimeoutTimer = createdTimers[#createdTimers]

assert(#createdCanvases == canvasesBeforeDisabledTimeout + 1 and
           #createdModals == modalsBeforeDisabledTimeout + 1 and
           #createdTimers == timersBeforeDisabledTimeout + 1,
       "zero timeout must create one interactive RetroUI dialog")
assert(disabledTimeoutCanvas.visible and disabledTimeoutCanvas.levelValue ==
           hs.canvas.windowLevels.floating and
           disabledTimeoutCanvas.clickActivatingValue == false and
           type(disabledTimeoutCanvas.mouseCallbackValue) == "function",
       "zero-timeout dialog must be a non-activating mouse-aware canvas")
assert(disabledTimeoutTimer.duration == 30,
       "zero-timeout dialog must own a thirty-second lifetime")
local disabledFooter = assert(elementById(disabledTimeoutCanvas,
                                         "retro-ui:footer:text"))
local disabledFace = assert(elementById(disabledTimeoutCanvas,
                                       "retro-ui:button:accept:face"))
local disabledShadow = assert(elementById(disabledTimeoutCanvas,
                                         "retro-ui:button:accept:shadow"))
assert(disabledTimeoutCanvas.elements[1].fillColor.green == 0.53 and
           disabledFooter.text.text == "This dialog will be dismissed in 30 seconds." and
           disabledFace.frame.x > disabledFooter.frame.x and
           disabledShadow.frame.x - disabledFace.frame.x == 6 and
           disabledShadow.frame.y - disabledFace.frame.y == 6 and
           disabledShadow.frame.x + disabledShadow.frame.w ==
               disabledTimeoutCanvas.currentFrame.w - 22,
       "zero timeout must use the Borland footer action layout")
assert(#createdWebviews == webviewsBeforeDisabledTimeout and
           #createdWebviewControllers == controllersBeforeDisabledTimeout and
           globalHotkeyBindCalls == hotkeysBeforeDisabledTimeout and
           defaultTextStyleCalls == fontCallsBeforeDisabledTimeout and
           interfaceStyleCalls == appearanceCallsBeforeDisabledTimeout and
           osascriptCalls == accentCallsBeforeDisabledTimeout,
       "zero timeout must not allocate a Gearbox runtime")

local function bareBinding(modal, key)
    for _, binding in ipairs(modal.bindingCalls) do
        if binding.key == key and #binding.modifiers == 0 then return binding end
    end
end

local returnBinding = assert(bareBinding(disabledTimeoutModal, "return"))
assert(bareBinding(disabledTimeoutModal, "a"),
       "Accept must bind its mnemonic")
returnBinding.pressed()
assert(disabledFace.frame.y == disabledShadow.frame.y,
       "Return down must move the button face over its shadow")
returnBinding.released()
assert(disabledFace.frame.y == disabledShadow.frame.y,
       "Return release must retain the pressed visual until dismissal")
createdTimers[#createdTimers]:fire()
assert(disabledTimeoutCanvas.visible == false and disabledTimeoutModal.deleted,
       "Return release must dismiss and clean the warning dialog")

local function startWarning()
    local accepted, result = pcall(function() return Gearbox.start() end)
    assert(accepted and result == nil,
           "each disabled configuration attempt must return after showing its warning")
    return createdCanvases[#createdCanvases], createdModals[#createdModals],
           createdTimers[#createdTimers]
end

local mouseWarningCanvas, mouseWarningModal = startWarning()
mouseButtons = {left = true}
mouseWarningCanvas.mouseCallbackValue(mouseWarningCanvas, "mouseDown",
                                      "retro-ui:button:accept:hit")
mouseButtons = {}
mouseWarningCanvas.mouseCallbackValue(mouseWarningCanvas, "mouseUp",
                                      "retro-ui:button:accept:hit")
local mouseFace = assert(elementById(mouseWarningCanvas,
                                    "retro-ui:button:accept:face"))
local mouseShadow = assert(elementById(mouseWarningCanvas,
                                      "retro-ui:button:accept:shadow"))
assert(mouseFace.frame.y == mouseShadow.frame.y,
       "mouse release must retain the pressed visual until dismissal")
createdTimers[#createdTimers]:fire()
assert(mouseWarningCanvas.visible == false and mouseWarningModal.deleted,
       "left mouse down/up must dismiss the warning through RetroUI")

local rightWarningCanvas, rightWarningModal, rightWarningTimer = startWarning()
mouseButtons = {right = true}
rightWarningCanvas.mouseCallbackValue(rightWarningCanvas, "mouseDown",
                                      "retro-ui:button:accept:hit")
mouseButtons = {}
rightWarningCanvas.mouseCallbackValue(rightWarningCanvas, "mouseUp",
                                      "retro-ui:button:accept:hit")
assert(rightWarningCanvas.visible and not rightWarningModal.deleted,
       "right clicks must not dismiss the warning")
rightWarningTimer:fire()
assert(rightWarningCanvas.visible == false and rightWarningModal.deleted,
       "the warning timeout must dismiss and clean the dialog")

local stopWarningCanvas, stopWarningModal = startWarning()
Gearbox.stop()
assert(stopWarningCanvas.visible == false and stopWarningModal.deleted,
       "Gearbox.stop must clean warning-only state")

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

local function sendCharacterKeyDown(character, options)
    options = options or {}

    local eventTap = options.eventTap or createdEventTaps[#createdEventTaps]

    assert(eventTap and eventTap.enabled,
           "character input requires an active Gearbox event tap")

    local flags = {}

    for modifier, enabled in pairs(options.flags or {}) do
        flags[modifier] = enabled
    end

    local physicalKey = options.physicalKey or character:lower()
    local keycode = options.keycode or keycodeMap[physicalKey]

    assert(keycode, "missing mocked keycode for " .. tostring(physicalKey))

    local event = {}

    -- Native AppKit probe, 2026-08-27: clean characters were w, W, w,
    -- W for none, Shift, Caps, and Caps+Shift. Hammerspoon 1.1.1 delegates
    -- getCharacters(true) to that same API.
    polledCapsLockEnabled = options.capsLock == true

    function event:getCharacters() return character end
    function event:getFlags() return flags end
    function event:getKeyCode() return keycode end
    function event:getProperty()
        if type(options.autorepeat) == "number" then
            return options.autorepeat
        end

        return options.autorepeat and 1 or 0
    end
    if not options.omitRawFlags then
        function event:rawFlags()
            return options.capsLock and
                       hs.eventtap.event.rawFlagMasks.alphaShift or 0
        end
    end

    local result = eventTap.callback(event)
    polledCapsLockEnabled = false
    return result
end

local staleWarningCanvas, staleWarningModal = startWarning()
local overridesAccepted, overridesError = pcall(function()
    Gearbox.start({})
end)

assert(not overridesAccepted and overridesError ==
           "Gearbox: edit Spoons/Gearbox/config.lua instead of passing overrides",
       "Gearbox.start must reject external configuration overrides")
assert(not staleWarningCanvas.visible and staleWarningModal.deleted,
       "every start attempt must clean a stale configuration dialog first")

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

local runtimeEventTap = createdEventTaps[#createdEventTaps]

assert(runtimeEventTap and not runtimeEventTap.enabled,
       "character input must remain disabled while Gearbox is idle")

capsLockRenderState.enabled = true
globalHotkeyPressed()
assert(runtime.activeMenu.id == "leader", "global hotkey must open leader")
assert(runtimeEventTap.enabled,
       "opening Gearbox must start character input")
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
assert(#createdWebviews == 0 and #createdWebviewControllers == 0,
       "scratchpad must not allocate WebKit objects during startup")
assert(runtime.hud.canvas.elements[1].roundedRectRadii.xRadius ==
           runtime.theme.metrics.windowCornerRadius,
       "menu HUD and scratchpad must share the outer corner radius")

assert(styledTextValue(assert(elementById(runtime.hud.canvas,
                                         "caps-lock-warning")).text) ==
           "CAPS LOCK" and
           elementById(runtime.hud.canvas,
                       "caps-lock-warning").text.segments[1].attributes.color ==
           runtime.theme.colors.background and
           assert(elementById(runtime.hud.canvas,
                              "caps-lock-warning-background")).fillColor ==
           runtime.theme.colors.primary,
       "enabled Caps Lock must render an inverse-color root-header warning")
assert(capsLockRenderState.reads == 1,
       "the root header must sample Caps Lock exactly when rendered")

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

assert(not findBinding(rootModal, "d", {}) and
           not findBinding(rootModal, "d", config.hotkey.modifiers),
       "character rows must not also own modal bindings")

assert(not findBinding(rootModal, "escape", config.hotkey.modifiers),
       "Escape must not shadow the native modified shortcut")

assert(not findBinding(rootModal, "down", config.hotkey.modifiers),
       "navigation arrows must not shadow modified system shortcuts")

assert(not findBinding(rootModal, "return", config.hotkey.modifiers),
       "Return activation must be bound without leader modifiers")

local downBinding = assert(findBinding(rootModal, "down", {}))

assert(downBinding.pressed and downBinding.repeated,
       "arrow navigation must run on key press and key repeat")

local dispatchedCharacters = {}
local originalLowercaseW = runtime.menus.leader.activationRowsByCharacter.w
local originalUppercaseW = runtime.menus.leader.activationRowsByCharacter.W

local function recordingRow(character)
    return {
        action = {
            type = "custom",
            run = function()
                table.insert(dispatchedCharacters, character)
                return {}
            end
        }
    }
end

runtime.menus.leader.activationRowsByCharacter.w = recordingRow("w")
runtime.menus.leader.activationRowsByCharacter.W = recordingRow("W")

assert(sendCharacterKeyDown("w") == true and
           sendCharacterKeyDown("W", {
            physicalKey = "w",
            flags = {shift = true}
        }) == true and sendCharacterKeyDown("w", {
            physicalKey = "w",
            capsLock = true
        }) == true and sendCharacterKeyDown("W", {
            physicalKey = "w",
            capsLock = true,
            flags = {shift = true}
        }) == true and table.concat(dispatchedCharacters, ",") == "w,W,W,w",
       "Shift and Caps Lock must select the exact resulting letter")

assert(sendCharacterKeyDown("W", {
    physicalKey = "w",
    flags = {alt = true, cmd = true, shift = true}
}) == true and dispatchedCharacters[#dispatchedCharacters] == "W",
       "configured command modifiers must preserve character case")

assert(sendCharacterKeyDown("w", {
    physicalKey = "w",
    capsLock = true,
    omitRawFlags = true
}) == true and dispatchedCharacters[#dispatchedCharacters] == "W",
       "the documented Caps Lock poll fallback must preserve resulting case")

assert(sendCharacterKeyDown("w", {
    physicalKey = "w",
    flags = {fn = true}
}) == true and dispatchedCharacters[#dispatchedCharacters] == "w",
       "Fn must not change character-command acceptance")

local dispatchCountBeforeRepeat = #dispatchedCharacters

assert(sendCharacterKeyDown("w", {autorepeat = 2}) == true and
           #dispatchedCharacters == dispatchCountBeforeRepeat,
       "every non-zero matched autorepeat must be consumed without redispatch")
assert(sendCharacterKeyDown("q") == nil,
       "an unmatched character must pass through")
assert(sendCharacterKeyDown("w", {flags = {ctrl = true}}) == nil,
       "an unsupported command chord must pass through")

runtime.menus.leader.activationRowsByCharacter.w = originalLowercaseW
runtime.menus.leader.activationRowsByCharacter.W = originalUppercaseW

local symbolDispatches = 0
local symbolRow = {
    action = {
        type = "custom",
        run = function()
            symbolDispatches = symbolDispatches + 1
            return {}
        end
    }
}

runtime.menus.leader.activationRowsByCharacter["1"] = symbolRow
runtime.menus.leader.activationRowsByCharacter["!"] = symbolRow

assert(sendCharacterKeyDown("1", {physicalKey = "1"}) == true and
           sendCharacterKeyDown("!", {
            physicalKey = "1",
            flags = {shift = true}
        }) == true and sendCharacterKeyDown("1", {
            physicalKey = "1",
            capsLock = true
        }) == true and symbolDispatches == 3,
       "digits and shifted symbols must dispatch independently of Caps Lock")

runtime.menus.leader.activationRowsByCharacter["1"] = nil
runtime.menus.leader.activationRowsByCharacter["!"] = nil

local function rowVisualByLabel(menu, label)
    for index, row in ipairs(menu.rows) do
        if row.label == label then return menu.rowVisuals[index] end
    end
end

assert(rowVisualByLabel(runtime.menus.leader, "Applications").keyBackgroundIndex,
       "root group keys must use the configured accent background")

assert(sendCharacterKeyDown("a") == true and
           runtime.activeMenu.id == "applications",
       "a must open the nested Applications menu")
assert(elementById(runtime.hud.canvas, "caps-lock-warning") == nil and
           capsLockRenderState.reads == 1,
       "child menus must not render or sample the root Caps Lock warning")
assert(runtimeEventTap.enabled,
       "menu transitions must retain the same character input tap")
assert(rowVisualByLabel(runtime.menus.applications, "Communications").keyBackgroundIndex,
       "nested group keys must use the configured accent background")
capsLockRenderState.enabled = false
runtime.menus.applications.modal.bindings.escape()
assert(elementById(runtime.hud.canvas, "caps-lock-warning") == nil and
           capsLockRenderState.reads == 2,
       "disabled Caps Lock must leave the root header unchanged")

assert(sendCharacterKeyDown("d", {flags = {alt = true, cmd = true}}) == true and
           runtime.activeMenu.id == "developer",
       "character rows must accept the configured command chord")
runtime.menus.developer.modal.bindings.escape()

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
assert(not runtimeEventTap.enabled,
       "an elapsed positive timeout must stop character input")
assert(#shownAlerts == 0,
       "an elapsed positive timeout must not show a dismissal message")

secureInputEnabled = true
globalHotkeyPressed()
assert(runtime.activeMenu == nil and not runtimeEventTap.enabled and
           shownAlerts[#shownAlerts].message:match("Secure Input"),
       "Secure Input must prevent a partial menu session")
secureInputEnabled = false

failNextEventTapStart = true
globalHotkeyPressed()
assert(runtime.activeMenu == nil and not runtimeEventTap.enabled and
           shownAlerts[#shownAlerts].message:match("could not start"),
       "a disabled event tap must prevent a partial menu session")

local eventTapCountBeforeReopen = #createdEventTaps

globalHotkeyPressed()
assert(#createdEventTaps == eventTapCountBeforeReopen and runtimeEventTap.enabled,
       "repeated sessions must reuse one Runtime-owned event tap")
runtime.menus.leader.modal.bindings.down()
runtime.menus.leader.modal.bindings["return"]()
assert(launchedApplication == "Calculator",
       "Return must activate selected entry")
assert(runtime.activeMenu == nil, "application launch must close Gearbox")
assert(not runtimeEventTap.enabled,
       "a close-result action must stop character input")

globalHotkeyPressed()
assert(sendCharacterKeyDown("C", {
    physicalKey = "c",
    flags = {shift = true}
}) == true and launchedApplication == "Calculator" and
           runtime.activeMenu == nil,
       "uppercase application characters must launch and close Gearbox")

globalHotkeyPressed()

failNextWebviewSetup = true

local failedScratchpadAccepted = pcall(function()
    sendCharacterKeyDown("s")
end)

assert(not failedScratchpadAccepted,
       "a first-use scratchpad construction failure must surface")
assert(runtime.activeMenu.id == "leader",
       "a first-use scratchpad failure must leave the menu active")
assert(runtimeEventTap.enabled,
       "a failed Scratchpad handoff must retain character input")
assert(#createdWebviews == 1 and createdWebviews[1].deleted and
           runtime.scratchpad.webview == nil,
       "a first-use scratchpad failure must delete its partial webview")
assert(#createdWebviewControllers == 1 and
           createdWebviewControllers[1].callback == nil and
           runtime.scratchpad.controller == nil,
       "a first-use scratchpad failure must release its controller")

sendCharacterKeyDown("s")

local scratchpadWebview = createdWebviews[2]
local scratchpadController = createdWebviewControllers[2]

assert(runtime.activeMenu == nil, "scratchpad must replace the menu HUD")
assert(not runtimeEventTap.enabled,
       "a successful Scratchpad handoff must stop character input")
assert(#createdWebviews == 2 and scratchpadWebview.visible,
       "scratchpad must create one usable webview on a successful retry")
assert(scratchpadController.name == "gearboxScratchpad",
       "scratchpad must use its private message bridge")
assert(scratchpadWebview.allowTextEntryValue == true and
           scratchpadWebview.transparentValue == true and
           scratchpadWebview.shadowValue == true and
           #scratchpadWebview.windowStyleValue == 0,
       "scratchpad must be an editable, transparent, borderless panel")
assert(scratchpadWebview.currentFrame.w == 720 and
           scratchpadWebview.currentFrame.h == 480 and
           scratchpadWebview.currentFrame.x == 600 and
           scratchpadWebview.currentFrame.y == 150,
       "scratchpad must use configured size and Gearbox placement")
assert(scratchpadWebview.document:match("Tab inserts tabs"),
       "scratchpad must include the non-editable instructions")
assert(scratchpadWebview.document:find('--interface-font: "Avenir Next",', 1,
                                       true) and
           scratchpadWebview.document:find(
               "editor.style.fontFamily = state.editorFontFamily", 1, true) and
           not scratchpadWebview.document:find("title.style.fontFamily", 1,
                                                true) and
           not scratchpadWebview.document:find(
               "instructions.style.fontFamily", 1, true),
       "scratchpad title and instructions must use the bundled macOS interface font")
assert(not scratchpadWebview.document:match('event.key === "Escape"'),
       "scratchpad must not bind Escape")

local scratchpadState = runtime.scratchpad:state(false)

assert(scratchpadState.instructions ==
           "Cursor keys move · Tab inserts tabs · alt+cmd+space closes scratchpad",
       "scratchpad instructions must include the configured Gearbox hotkey")
assert(scratchpadState.bodySize == 14 and scratchpadState.footerSize == 13,
       "scratchpad font sizing must remain configurable and legible")
assert(scratchpadState.editorFontFamily == "System",
       "scratchpad editor must retain the resolved Gearbox font")
assert(scratchpadState.maxCharacters == 4096 and
           scratchpadWebview.document:match(
               "editor.maxLength = state.maxCharacters"),
       "scratchpad must expose its configured capacity to the native editor")

scratchpadController.callback({
    action = "save",
    content = "persistent draft"
})

assert(settings["Gearbox.scratchpad.content"] == "persistent draft",
       "scratchpad content must persist through hs.settings")

scratchpadWebview.contentResult = "persistent draft"
globalHotkeyPressed()
assert(not scratchpadWebview.visible,
       "global Gearbox hotkey must hide the scratchpad")

globalHotkeyPressed()
sendCharacterKeyDown("s")
assert(#createdWebviews == 2 and scratchpadWebview.visible,
       "scratchpad must reuse its existing webview")

scratchpadWebview.contentResult = "reopened draft"
globalHotkeyPressed()

assert(
    not scratchpadWebview.visible and settings["Gearbox.scratchpad.content"] ==
        "reopened draft",
    "Gearbox hotkey must save and hide the reopened scratchpad")

globalHotkeyPressed()
sendCharacterKeyDown("m")
assert(runtime.activeMenu.id == "macos", "m must open macOS Utilities")

local styleCallsBeforeHUDRefresh = interfaceStyleCalls

sendCharacterKeyDown("a")
assert(Actions.currentCaffeinateMode() == "display",
       "display mode action must remain active after HUD refresh")
assert(runtime.activeMenu.id == "macos",
       "changing a power mode must keep macOS Utilities open")
assert(interfaceStyleCalls == styleCallsBeforeHUDRefresh,
       "HUD-only refreshes must not resolve system appearance")

runtime.menus.macos.modal.bindings.escape()
sendCharacterKeyDown("g")
assert(runtime.activeMenu.id == "configuration" and
           runtime.activeMenu.title == "Gearbox Configuration",
       "g must open Gearbox Configuration")

assert(styledTextValue(assert(elementById(runtime.hud.canvas,
                                         "menu-legend")).text) ==
           runtime.menus.configuration.legend and
           elementById(runtime.hud.canvas,
                       "menu-legend").text.segments[1].attributes.color ==
           runtime.theme.colors.secondary,
       "Gearbox Configuration must render its trigger legend subdued")

sendCharacterKeyDown("h")
assert(reloadCalls == 2 and runtime.activeMenu.id == "configuration",
       "Reload Hammerspoon must be owned by Gearbox Configuration")

sendCharacterKeyDown("t")
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

sendCharacterKeyDown("c")

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
sendCharacterKeyDown("s")

assert(runtime.theme.selection == "system", "system selection must be restored")
assert(runtime.theme.activeThemeId == "gearbox-light",
       "system selection must resolve the light appearance")
assert(checkedThemeKeys() == "s", "system must regain the exclusive check")

interfaceStyle = "Dark"
runtime.menus.themes.modal.bindings.escape()

assert(runtime.theme.activeThemeId == "gearbox-dark",
       "modal entry must re-evaluate the system appearance")

sendCharacterKeyDown("t")
sendCharacterKeyDown("r")

assert(runtime.theme.selection == "dracula",
       "manual selection must switch away from system mode")

runtime.menus.themes.modal.bindings.escape()
assert(runtime.activeMenu.id == "configuration",
       "Themes must return to Gearbox Configuration")

sendCharacterKeyDown("m")
sendCharacterKeyDown("b")

assert(runtime.config.menu.position == "bottom" and
           settings["Gearbox.preferences.local.v1"].menu.position == "bottom",
       "menu position changes must apply immediately and persist locally")
assert(package.loaded[configModule].menu.position == "top",
       "runtime preferences must not mutate the cached config.lua table")

local positionChecks = runtime:checkedRows(runtime.menus["menu-position"])

assert(positionChecks[2] and not positionChecks[1],
       "only the effective menu position must be checked")

runtime.menus["menu-position"].modal.bindings.escape()
sendCharacterKeyDown("s")

sendCharacterKeyDown("p")
assert(runtime.config.scratchpad.persistContent == false,
       "Scratchpad persistence must toggle off")
sendCharacterKeyDown("p")
assert(runtime.config.scratchpad.persistContent == true,
       "Scratchpad persistence must toggle back on")

local sharedDirectory = homeDirectory .. "/Shared Gearbox"
fileModes[sharedDirectory] = "directory"
table.insert(chosenPaths, {sharedDirectory})
sendCharacterKeyDown("f")

assert(runtime.config.scratchpad.storagePath ==
           "~/Shared Gearbox/scratchpad.txt",
       "folder selection must store a portable external path")

table.insert(promptResponses, {button = "Save", text = "notes.txt"})
sendCharacterKeyDown("n")
table.insert(promptResponses, {button = "Save", text = "900"})
sendCharacterKeyDown("w")
table.insert(promptResponses, {button = "Save", text = "640"})
sendCharacterKeyDown("e")

assert(runtime.config.scratchpad.storagePath == "~/Shared Gearbox/notes.txt" and
           runtime.config.scratchpad.width == 900 and
           runtime.config.scratchpad.height == 640,
       "Scratchpad filename and dimensions must update the effective config")
assert(runtime.menus["scratchpad-settings"].rows[4].label ==
           "Filename: notes.txt" and
           runtime.menus["scratchpad-settings"].rows[6].label ==
           "Width: 900 pt" and
           runtime.menus["scratchpad-settings"].rows[7].label ==
           "Height: 640 pt",
       "value-bearing Scratchpad rows must refresh their labels")

runtime.menus["scratchpad-settings"].modal.bindings.escape()
sendCharacterKeyDown("p")

local savedProfile = assert(jsonFiles[preferencesPath])

assert(savedProfile.schemaVersion == 1 and
           savedProfile.menu.position == "bottom" and
           savedProfile.scratchpad.storage.backend == "file" and
           savedProfile.scratchpad.storage.path ==
           "~/Shared Gearbox/notes.txt" and savedProfile.scratchpad.width == 900 and
           savedProfile.scratchpad.height == 640,
       "Save Versioned Profile must write the complete portable state")
assert(settings["Gearbox.preferences.local.v1"] == nil,
       "saving the profile must clear redundant local overrides")

sendCharacterKeyDown("m")
sendCharacterKeyDown("t")
runtime.menus["menu-position"].modal.bindings.escape()
sendCharacterKeyDown("x")

assert(runtime.config.menu.position == "bottom",
       "resetting local overrides must restore the versioned profile")

savedProfile.menu.position = "top"
sendCharacterKeyDown("r")

assert(runtime.config.menu.position == "top",
       "Reload Versioned Profile must apply external profile changes")

local storagePath = os.tmpname() .. "-gearbox-scratchpad.txt"
local storageDirectory = storagePath:match("^(.*)/[^/]+$")
local storageConfig = {scratchpad = {storagePath = storagePath}}
local storage = ScratchpadStorage.new(storageConfig)

fileModes[storageDirectory] = "directory"
os.remove(storagePath)

local missingContent, missingError = storage:load()

assert(missingContent == "" and missingError == nil,
       "a missing external Scratchpad file must begin empty")
assert(storage:save("shared draft"),
       "external Scratchpad content must save successfully")

fileModes[storagePath] = "file"

local storedContent = assert(storage:load())

assert(storedContent == "shared draft",
       "external Scratchpad content must round-trip as UTF-8 text")
assert(io.open(storagePath .. ".gearbox.tmp", "rb") == nil,
       "successful external writes must not leave a temporary file")

runtime.preferences:setStorage({backend = "file", path = storagePath})
runtime.menus.configuration.modal.bindings.escape()
sendCharacterKeyDown("s")

assert(runtime.scratchpad.content == "shared draft",
       "opening Scratchpad must load the selected external file")

scratchpadWebview.contentResult = "shared draft"
globalHotkeyPressed()

local externalFile = assert(io.open(storagePath, "wb"))
assert(externalFile:write("remote update"))
assert(externalFile:close())

globalHotkeyPressed()
sendCharacterKeyDown("s")

assert(runtime.scratchpad.content == "remote update",
       "reopening Scratchpad must load changes written by another host")

local unwritablePath = "/mock-only-directory/notes.txt"
fileModes["/mock-only-directory"] = "directory"
runtime.preferences:setStorage({backend = "file", path = unwritablePath})
scratchpadWebview.contentResult = "unsaved update"
local alertsBeforeWriteFailure = #shownAlerts
globalHotkeyPressed()

assert(scratchpadWebview.visible and
           #shownAlerts == alertsBeforeWriteFailure + 1,
       "external write failures must keep the Scratchpad visible")

globalHotkeyPressed()
assert(#shownAlerts == alertsBeforeWriteFailure + 1,
       "repeated identical storage failures must not repeat alerts")

runtime.preferences:setStorage({backend = "file", path = storagePath})
globalHotkeyPressed()

runtime.preferences:setStorage({backend = "file", path = "/missing/notes.txt"})
globalHotkeyPressed()
local alertsBeforeReadFailure = #shownAlerts
sendCharacterKeyDown("s")

assert(runtime.activeMenu.id == "leader" and
           #shownAlerts == alertsBeforeReadFailure + 1,
       "external read failures must remain visible without closing Gearbox")
assert(settings["Gearbox.scratchpad.content"] == "reopened draft",
       "external storage failures must never fall back to hs.settings")

os.remove(storagePath)
fileModes[storagePath] = nil
jsonFiles[preferencesPath] = nil
fileModes[preferencesPath] = nil
settings["Gearbox.preferences.local.v1"] = nil

local validRuntime = runtime
local canvasesBeforeFailedReplacement = #createdCanvases
local modalsBeforeFailedReplacement = #createdModals
local timersBeforeFailedReplacement = #createdTimers
local webviewsBeforeFailedReplacement = #createdWebviews
local controllersBeforeFailedReplacement = #createdWebviewControllers
local hotkeysBeforeFailedReplacement = globalHotkeyBindCalls
local fontCallsBeforeFailedReplacement = defaultTextStyleCalls
local failedReplacementAccepted, failedReplacementResult = pcall(function()
    return startGearbox({menu = {timeout = 0}})
end)

assert(failedReplacementAccepted and failedReplacementResult == validRuntime,
       "zero-timeout replacement must return the preserved runtime")
assert(
    #createdCanvases == canvasesBeforeFailedReplacement + 1 and
        #createdModals == modalsBeforeFailedReplacement + 1 and #createdTimers ==
        timersBeforeFailedReplacement + 1 and #createdWebviews ==
        webviewsBeforeFailedReplacement and #createdWebviewControllers ==
        controllersBeforeFailedReplacement and globalHotkeyBindCalls ==
        hotkeysBeforeFailedReplacement and defaultTextStyleCalls ==
        fontCallsBeforeFailedReplacement,
    "zero-timeout replacement must only allocate its configuration dialog")
assert(validRuntime.started and validRuntime.activeMenu == nil,
       "zero-timeout replacement must preserve the runtime while closing its visible menu")
assert(not validRuntime.characterInputTap.enabled,
       "zero-timeout replacement must stop the preserved runtime's input tap")

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
assert(validRuntime.activeMenu == nil,
       "invalid overrides must preserve the closed runtime state")

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
assert(validRuntime.activeMenu == nil,
       "invalid keys must preserve the closed runtime state")

local reservedCaseAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, navigation = {activateKey = "Down"}})
end)

assert(not reservedCaseAccepted,
       "reserved navigation keys must be compared case-insensitively")
assert(validRuntime.activeMenu == nil,
       "reserved key failures must preserve the closed runtime state")

local smallScratchpadAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, scratchpad = {width = 359}})
end)

assert(not smallScratchpadAccepted,
       "undersized scratchpad dimensions must fail early")
assert(validRuntime.activeMenu == nil,
       "scratchpad validation failures must preserve the closed runtime state")

local invalidScratchpadCapacityAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, scratchpad = {maxCharacters = 0}})
end)

assert(not invalidScratchpadCapacityAccepted,
       "scratchpad capacity must be a positive integer")
assert(validRuntime.activeMenu == nil,
       "scratchpad capacity failures must preserve the closed runtime state")

local invalidScratchpadFontSizeAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, scratchpad = {fontSize = 0}})
end)

assert(not invalidScratchpadFontSizeAccepted,
       "scratchpad font size must be positive")
assert(validRuntime.activeMenu == nil,
       "scratchpad font-size failures must preserve the closed runtime state")

local fontCallsBeforePartialStart = defaultTextStyleCalls
local partialStartModalIndex = #createdModals + 1
local eventTapsBeforePartialStart = #createdEventTaps
failNextModalBind = true

local partialStartAccepted = pcall(function()
    startGearbox({menu = {timeout = 5}, theme = {accentSource = "theme"}})
end)

assert(not partialStartAccepted, "partial modal registration must fail startup")
assert(#createdEventTaps == eventTapsBeforePartialStart + 1 and
           not createdEventTaps[#createdEventTaps].enabled,
       "partial startup must stop its candidate event tap")

for index = partialStartModalIndex, #createdModals do
    assert(createdModals[index].deleted,
           "partial startup must delete every candidate modal")
end

assert(validRuntime.started, "partial startup must preserve the active runtime")
assert(defaultTextStyleCalls == fontCallsBeforePartialStart + 1,
       "a failed candidate must resolve fonts only once")
assert(validRuntime.activeMenu == nil,
       "partial startup must preserve the closed runtime state")

local fontCallsBeforeGlobalFailure = defaultTextStyleCalls
local globalFailureModalIndex = #createdModals + 1
local eventTapsBeforeGlobalFailure = #createdEventTaps
failNextGlobalHotkey = true

local unavailableHotkeyAccepted = pcall(function()
    startGearbox({
        menu = {timeout = 5},
        theme = {name = "gearbox-light", accentSource = "theme"}
    })
end)

assert(not unavailableHotkeyAccepted,
       "unavailable global hotkeys must fail startup")
assert(#createdEventTaps == eventTapsBeforeGlobalFailure + 1 and
           not createdEventTaps[#createdEventTaps].enabled,
       "global-hotkey failure must stop its candidate event tap")
assert(validRuntime.started,
       "failed hotkey registration must not stop the active runtime")
assert(validRuntime.activeMenu == nil,
       "failed hotkey registration must preserve the closed runtime state")
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

local bottomRuntime = startGearbox({
    menu = {timeout = 5, position = "bottom"},
    scratchpad = {fontSize = 18},
    theme = {accentSource = "theme"}
})

globalHotkeyPressed()

local bottomMenuFrame = bottomRuntime.hud.canvas.currentFrame
local bottomMenuMargin = 1080 - bottomMenuFrame.y - bottomMenuFrame.h

assert(bottomMenuMargin == (1080 - bottomMenuFrame.h) * 0.25,
       "bottom HUD placement must mirror the top margin")

sendCharacterKeyDown("s")

local bottomScratchpad = createdWebviews[#createdWebviews]
local bottomScratchpadFrame = bottomScratchpad.currentFrame
local bottomScratchpadState = bottomRuntime.scratchpad:state(false)

assert(bottomScratchpadFrame.y == 450 and
           1080 - bottomScratchpadFrame.y - bottomScratchpadFrame.h == 150,
       "bottom scratchpad placement must mirror the top margin")
assert(bottomScratchpadState.bodySize == 18 and
           bottomScratchpadState.footerSize == 17,
       "scratchpad font size must reach the webview state")

local unhighlightedGroupRuntime = startGearbox({
    menu = {timeout = 5, highlightGroups = false},
    theme = {accentSource = "theme"}
})

globalHotkeyPressed()
assert(rowVisualByLabel(unhighlightedGroupRuntime.menus.leader, "Applications").keyBackgroundIndex ==
           nil, "disabled group highlighting must apply to the root menu")
sendCharacterKeyDown("a")
assert(rowVisualByLabel(unhighlightedGroupRuntime.menus.applications,
                        "Communications").keyBackgroundIndex == nil,
       "disabled group highlighting must apply to nested menus")
globalHotkeyPressed()

local letterToggleRuntime = startGearbox({
    hotkey = {key = "g"},
    menu = {timeout = 5},
    theme = {accentSource = "theme"}
})

assert(letterToggleRuntime.menus.configuration.legend ==
           "Trigger: ⌥⌘G · Customizable via Spoon docs",
       "configuration legend must follow a customized trigger key")

globalHotkeyPressed()
assert(sendCharacterKeyDown("g", {
    flags = {alt = true, cmd = true}
}) == nil and letterToggleRuntime.activeMenu.id == "leader",
       "the configured global chord must pass through without dispatching its row")

local shiftedToggleDispatches = 0
letterToggleRuntime.menus.leader.activationRowsByCharacter.G = {
    action = {
        type = "custom",
        run = function()
            shiftedToggleDispatches = shiftedToggleDispatches + 1
            return {}
        end
    }
}

assert(sendCharacterKeyDown("G", {
    physicalKey = "g",
    flags = {alt = true, cmd = true, shift = true}
}) == nil and shiftedToggleDispatches == 0 and
           letterToggleRuntime.activeMenu.id == "leader",
       "a same-key chord with extra Shift must remain reserved for the toggle")

assert(sendCharacterKeyDown("g", {
    flags = {alt = true, cmd = true, fn = true}
}) == nil and letterToggleRuntime.activeMenu.id == "leader",
       "a same-key chord with Fn must remain reserved for the toggle")

letterToggleRuntime.menus.leader.activationRowsByCharacter.G = nil
globalHotkeyPressed()

local shiftHotkeyRuntime = startGearbox({
    hotkey = {modifiers = {"cmd", "shift"}},
    menu = {timeout = 5},
    theme = {accentSource = "theme"}
})

assert(shiftHotkeyRuntime.menus.configuration.legend ==
           "Trigger: ⌘⇧Space · Customizable via Spoon docs",
       "configuration legend must follow customized trigger modifiers")

globalHotkeyPressed()
assert(sendCharacterKeyDown("w", {flags = {cmd = true}}) == true and
           shiftHotkeyRuntime.activeMenu.id == "browsers",
       "Shift in the global chord must remain character state inside menus")
shiftHotkeyRuntime.menus.browsers.modal.bindings.escape()
globalHotkeyPressed()

local noScratchpadRuntime = startGearbox({
    menu = {timeout = 5},
    scratchpad = {enable = false},
    theme = {accentSource = "theme"}
})

assert(noScratchpadRuntime.menus.leader.activationRowsByCharacter.s == nil,
       "disabled scratchpad must not register a root-menu character")

Gearbox.stop()

print("Gearbox smoke test passed")
