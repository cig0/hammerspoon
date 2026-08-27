--- Menu-session input runtime.
--
-- Owns the global hotkey, session character capture, named modal controls,
-- navigation, timeouts, and action dispatch. Input: assembled menus from
-- `loader.lua`. Output: menu-session lifecycle and HUD updates.
local Runtime = {}
local Validation = require("Spoons.Gearbox.validation")

local hotkeyIdentity = Validation.hotkeyIdentity
local isCharacterActivationKey = Validation.isCharacterActivationKey

local hotkeyModifierAliases = {
    alt = "alt",
    option = "alt",
    cmd = "cmd",
    command = "cmd",
    ctrl = "ctrl",
    control = "ctrl",
    shift = "shift"
}

--- Resolve the configured hotkey modifiers to event-flag names.
---
--- Shift remains character state even when it is part of the global hotkey.
---@param modifiers table
---@return table
local function resolveRequiredHotkeyModifiers(modifiers)
    local required = {alt = false, cmd = false, ctrl = false, shift = false}

    for _, modifier in ipairs(modifiers) do
        local canonicalName = hotkeyModifierAliases[modifier]

        if canonicalName then required[canonicalName] = true end
    end

    return required
end

--- Return true when an event has no Command, Option, or Control modifiers.
---@param flags table
---@return boolean
local function hasNoCharacterCommandModifiers(flags)
    return flags.alt ~= true and flags.cmd ~= true and flags.ctrl ~= true
end

--- Return true when event Command, Option, and Control flags match `required`.
---@param flags table
---@param required table
---@return boolean
local function matchesCharacterCommandModifiers(flags, required)
    return (flags.alt == true) == required.alt and
               (flags.cmd == true) == required.cmd and
               (flags.ctrl == true) == required.ctrl
end

--- Return true when event flags include the configured global-hotkey modifiers.
---@param flags table
---@param required table
---@return boolean
local function includesRequiredHotkeyModifiers(flags, required)
    return (not required.alt or flags.alt == true) and
               (not required.cmd or flags.cmd == true) and
               (not required.ctrl or flags.ctrl == true) and
               (not required.shift or flags.shift == true)
end

--- Resolve a named or raw Hammerspoon hotkey to its virtual keycode.
---@param key string
---@return integer|nil
local function resolveHotkeyKeyCode(key)
    local rawKeyCode = key:match("^#(%d+)$")

    if rawKeyCode then return tonumber(rawKeyCode) end

    return hs.keycodes.map[key:lower()]
end

--- Return true when `rawFlags` contains the power-of-two `flagMask`.
---@param rawFlags integer
---@param flagMask integer
---@return boolean
local function containsRawFlag(rawFlags, flagMask)
    return math.floor(rawFlags / flagMask) % 2 == 1
end

--- Return the Caps Lock state recorded on the key event.
---@param event any
---@return boolean
local function eventHasCapsLock(event)
    local rawFlagMasks = hs.eventtap.event.rawFlagMasks

    if event.rawFlags and rawFlagMasks and rawFlagMasks.alphaShift then
        return containsRawFlag(event:rawFlags(), rawFlagMasks.alphaShift)
    end

    return hs.eventtap.checkKeyboardModifiers().capslock == true
end

--- Invert one ASCII letter and leave every other character unchanged.
---@param character string
---@return string
local function invertAsciiLetterCase(character)
    if character:match("^[a-z]$") then return character:upper() end

    if character:match("^[A-Z]$") then return character:lower() end

    return character
end

--- Return the resulting activation character for a keyboard event.
---@param event any
---@return string|nil
local function activationCharacterForEvent(event)
    local character = event:getCharacters(true)

    if not isCharacterActivationKey(character) then return nil end

    -- Clean characters preserve Shift but omit Caps Lock; see README provenance.
    if eventHasCapsLock(event) then
        character = invertAsciiLetterCase(character)
    end

    return character
end

---@class Runtime
---@field config table
---@field menus table
---@field rootId string
---@field actions table
---@field theme table
---@field preferences table
---@field hud table
---@field scratchpad table|nil
---@field activeMenu table|nil
---@field timeoutTimer any
---@field globalHotkey any
---@field characterInputTap any
---@field requiredHotkeyModifiers table
---@field globalHotkeyKeyCode integer|nil
---@field started boolean
Runtime.__index = Runtime

--- Create a new runtime instance.
---@param config table
---@param menus table
---@param rootId string
---@param actions table
---@param theme table
---@param preferences table
---@param hud table
---@return Runtime
function Runtime.new(config, menus, rootId, actions, theme, preferences, hud,
                     scratchpad)
    local self = setmetatable({}, Runtime)

    self.config = config
    self.menus = menus
    self.rootId = rootId
    self.actions = actions
    self.theme = theme
    self.preferences = preferences
    self.hud = hud
    self.scratchpad = scratchpad

    self.activeMenu = nil
    self.timeoutTimer = nil
    self.globalHotkey = nil
    self.characterInputTap = nil
    self.requiredHotkeyModifiers = nil
    self.globalHotkeyKeyCode = nil
    self.started = false

    return self
end

--- Cancel the active auto-close timer.
function Runtime:clearTimeout()
    if self.timeoutTimer then
        self.timeoutTimer:stop()
        self.timeoutTimer = nil
    end
end

--- Restart the auto-close timer for `menu`.
---@param menu table
function Runtime:resetTimeout(menu)
    self:clearTimeout()

    if self.config.menu.timeout <= 0 then return end

    self.timeoutTimer = hs.timer.doAfter(self.config.menu.timeout, function()
        if self.activeMenu == menu then self:endMenuSession() end
    end)
end

--- Bind a bare (unmodified) key in a modal.
---@param modal table
---@param key string
---@param callback function
function Runtime:bindBare(modal, key, callback) modal:bind({}, key, callback) end

--- Bind a key both bare and with the configured Gearbox modifiers.
--
-- Skips the modifier binding when the key matches the global toggle key so that
-- pressing the toggle again closes Gearbox instead of firing a menu action.
---@param modal table
---@param key string
---@param callback function
function Runtime:bindFlexible(modal, key, callback)
    self:bindBare(modal, key, callback)

    -- Preserve the global toggle when a menu key matches its unmodified key.
    if hotkeyIdentity(key) ~= hotkeyIdentity(self.config.hotkey.key) then
        modal:bind(self.config.hotkey.modifiers, key, callback)
    end
end

--- Bind a key that repeats while held.
---@param modal table
---@param key string
---@param callback function
function Runtime:bindRepeating(modal, key, callback)
    -- Hammerspoon's message-less overload expects pressedfn in position three.
    modal:bind({}, key, callback, nil, callback)
end

--- Determine which rows should show a checkmark.
---@param menu table
---@return table
function Runtime:checkedRows(menu)
    local checked = {}
    local caffeinateMode

    for index, row in ipairs(menu.rows) do
        if not row.divider and row.checkable then
            if row.action.type == "setCaffeinateMode" then
                caffeinateMode = caffeinateMode or
                                     self.actions.currentCaffeinateMode()

                checked[index] = row.action.mode == caffeinateMode
            elseif row.action.type == "setTheme" then
                checked[index] = self.theme:isSelected(row.action.theme)
            elseif row.action.type == "configure" then
                checked[index] = self.preferences:isSelected(row.action)
            end
        end
    end

    return checked
end

--- Transition from `currentMenu` to the menu identified by `targetId`.
---@param currentMenu table
---@param targetId string
function Runtime:switchMenu(currentMenu, targetId)
    local target = self.menus[targetId]

    assert(target, "Gearbox: action references missing menu: " .. targetId)

    currentMenu.modal:exit()
    target.modal:enter()
end

--- Start character capture and enter the root menu.
---@return boolean
function Runtime:beginMenuSession()
    if hs.eventtap.isSecureInputEnabled() then
        hs.alert.show("Gearbox cannot capture keys while Secure Input is active")
        return false
    end

    self.characterInputTap:start()

    if not self.characterInputTap:isEnabled() then
        self.characterInputTap:stop()
        hs.alert.show("Gearbox could not start character input")
        return false
    end

    self.menus[self.rootId].modal:enter()
    return true
end

--- End the active Gearbox menu session and stop character capture.
function Runtime:endMenuSession()
    if self.characterInputTap then self.characterInputTap:stop() end

    if self.activeMenu then self.activeMenu.modal:exit() end
end

--- Handle one key-down event while a Gearbox menu session is active.
---@param event any
---@return boolean|nil
function Runtime:handleCharacterKeyDown(event)
    local menu = self.activeMenu

    if not menu then return nil end

    local flags = event:getFlags()

    if not hasNoCharacterCommandModifiers(flags) and
        not matchesCharacterCommandModifiers(
            flags, self.requiredHotkeyModifiers) then return nil end

    if event:getKeyCode() == self.globalHotkeyKeyCode and
        includesRequiredHotkeyModifiers(flags,
                                        self.requiredHotkeyModifiers) then
        return nil
    end

    local character = activationCharacterForEvent(event)

    if not character then return nil end

    local row = menu.activationRowsByCharacter[character]

    if not row then return nil end

    local autorepeatProperty =
        hs.eventtap.event.properties.keyboardEventAutorepeat

    if event:getProperty(autorepeatProperty) ~= 0 then return true end

    self:runAction(menu, row)
    return true
end

--- Execute a row's action and update the menu state.
---@param menu table
---@param row table
function Runtime:runAction(menu, row)
    local result = self.actions.execute(row.action, {
        openMenu = function(targetId) self:switchMenu(menu, targetId) end,
        exit = function() self:endMenuSession() end,
        setTheme = function(selection) self.theme:select(selection) end,
        configure = function(action) self.preferences:execute(action) end,
        openScratchpad = function()
            assert(self.scratchpad, "Gearbox: scratchpad is disabled")

            if self.scratchpad:show() then self:endMenuSession() end
        end
    })

    if result.handled then return end

    if result.refresh then
        self.preferences:refreshMenu(menu)
        self.hud:refresh(menu, self:checkedRows(menu))

        if self.config.navigation.resetTimeoutOnInput then
            self:resetTimeout(menu)
        end
    elseif result.close then
        self:endMenuSession()
    end
end

--- Move the selection up or down by `direction` rows.
---@param menu table
---@param direction integer
function Runtime:moveSelection(menu, direction)
    local count = #menu.navigableRows

    if count == 0 then return end

    if not menu.selectedPosition then
        menu.selectedPosition = direction > 0 and 1 or count
    else
        local nextPosition = menu.selectedPosition + direction

        if self.config.navigation.wrap then
            menu.selectedPosition = ((nextPosition - 1) % count) + 1
        else
            menu.selectedPosition = math.max(1, math.min(count, nextPosition))
        end
    end

    menu.selectedIndex = menu.navigableRows[menu.selectedPosition]
    self.hud:select(menu)

    if self.config.navigation.resetTimeoutOnInput then
        self:resetTimeout(menu)
    end
end

--- Activate the currently selected row, if any.
---@param menu table
function Runtime:activateSelection(menu)
    if not menu.selectedIndex then return end

    local row = menu.rows[menu.selectedIndex]

    if row and row.action then self:runAction(menu, row) end
end

--- Register hotkeys and lifecycle callbacks for `menu`.
---@param menu table
function Runtime:registerMenu(menu)
    menu.navigableRows = {}

    for index, row in ipairs(menu.rows) do
        if not row.divider then
            local callback = function() self:runAction(menu, row) end

            -- See menus/README.md for character versus modal key ownership.
            if row.kind == "footer" then
                self:bindBare(menu.modal, row.key, callback)
            elseif not isCharacterActivationKey(row.key) then
                self:bindFlexible(menu.modal, row.key, callback)
            end

            if row.kind ~= "footer" or self.config.navigation.includeFooter then
                table.insert(menu.navigableRows, index)
            end
        end
    end

    if self.config.navigation.enabled then
        self:bindRepeating(menu.modal, "up",
                           function() self:moveSelection(menu, -1) end)

        self:bindRepeating(menu.modal, "down",
                           function() self:moveSelection(menu, 1) end)

        self:bindBare(menu.modal, self.config.navigation.activateKey,
                      function() self:activateSelection(menu) end)
    end

    menu.modal.entered = function()
        self.activeMenu = menu
        menu.selectedIndex = nil
        menu.selectedPosition = nil

        self.theme:refreshAppearance()
        self.preferences:refreshMenu(menu)
        self.hud:show(menu, self:checkedRows(menu))
        self:resetTimeout(menu)
    end

    menu.modal.exited = function()
        if self.activeMenu == menu then self.activeMenu = nil end

        menu.selectedIndex = nil
        menu.selectedPosition = nil

        self.hud:close()
        self:clearTimeout()
    end
end

--- Delete the global hotkey and all modal bindings.
function Runtime:deleteBindings()
    if self.characterInputTap then
        self.characterInputTap:stop()
        self.characterInputTap = nil
    end

    if self.globalHotkey then
        self.globalHotkey:delete()
        self.globalHotkey = nil
    end

    for _, menu in pairs(self.menus) do menu.modal:delete() end
end

--- Start the runtime and register all bindings.
---@return Runtime
function Runtime:start()
    if self.started then return self end

    local started, startError = xpcall(function()
        self.requiredHotkeyModifiers =
            resolveRequiredHotkeyModifiers(self.config.hotkey.modifiers)
        self.globalHotkeyKeyCode =
            assert(resolveHotkeyKeyCode(self.config.hotkey.key),
                   "Gearbox: cannot resolve the global hotkey keycode")

        self.characterInputTap = hs.eventtap.new({
            hs.eventtap.event.types.keyDown
        }, function(event)
            return self:handleCharacterKeyDown(event)
        end)

        if not self.characterInputTap then
            error("Gearbox: failed to create the character input tap", 0)
        end

        for _, menu in pairs(self.menus) do self:registerMenu(menu) end

        self.globalHotkey = hs.hotkey.bind(self.config.hotkey.modifiers,
                                           self.config.hotkey.key, function()
            if self.scratchpad and self.scratchpad:isVisible() then
                self.scratchpad:hide()
            elseif self.activeMenu then
                self:endMenuSession()
            else
                self:beginMenuSession()
            end
        end)

        if not self.globalHotkey then
            error("Gearbox: failed to register the global hotkey", 0)
        end

        self.theme:activate()
    end, debug.traceback)

    if not started then
        if self.scratchpad then self.scratchpad:delete() end

        self:deleteBindings()
        error(startError, 0)
    end

    self.started = true
    return self
end

--- Stop the runtime, close the HUD, and clear all bindings.
function Runtime:stop()
    if not self.started then return end

    self:endMenuSession()

    self:clearTimeout()
    self.hud:close()

    if self.scratchpad then self.scratchpad:delete() end

    self:deleteBindings()

    self.started = false
end

return Runtime
