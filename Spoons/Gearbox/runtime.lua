--- Menu-session input runtime.
--
-- Owns the global hotkey, session keyboard observation, named modal controls,
-- navigation, timeouts, and action dispatch. Input: assembled menus from
-- `loader.lua`. Output: menu-session lifecycle and HUD updates.
local Runtime = {}
local Validation = require("Spoons.Gearbox.validation")

local hotkeyIdentity = Validation.hotkeyIdentity
local isCharacterActivationKey = Validation.isCharacterActivationKey

--- Resolve quickLaunch target for both map { [key]=target } and tuple list {{key,target}}.
---@param config table
---@param key string
---@return any
local function quickLaunchTarget(config, key)
  local ql = config.quickLaunch
  if not ql then return nil end
  if ql[1] ~= nil and type(ql[1]) == "table" and ql[1].key ~= nil then
    for _, entry in ipairs(ql) do
      if entry.key == key then return entry.target end
    end
    return nil
  end
  return ql[key]
end

--- Return true when quickLaunch has any entries (map or tuple list).
---@param config table
---@return boolean
local function hasQuickLaunch(config)
  local ql = config.quickLaunch
  if not ql then return false end
  if ql[1] ~= nil and type(ql[1]) == "table" then return #ql > 0 end
  return next(ql) ~= nil
end

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
  local required = { alt = false, cmd = false, ctrl = false, shift = false }

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
---@field sessionInputTap any
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
  self.quickLaunchHotkeys = {}
  self.sessionInputTap = nil
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
      elseif row.action.type == "setMatchingTheme" then
        checked[index] = self.theme:isMatchingTheme(row.action.theme)
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
--- Find the navigable position of `row` inside `menu` (1-based), or nil.
---@param menu table
---@param row table
---@return integer|nil
local function navigablePositionForRow(menu, row)
  for position, rowIndex in ipairs(menu.navigableRows) do
    if menu.rows[rowIndex] == row then return position end
  end
end

--- Find the navigable position in `parent` that opens `childId`.
---@param parent table
---@param childId string
---@return integer|nil
local function navigablePositionForChild(parent, childId)
  for position, rowIndex in ipairs(parent.navigableRows) do
    local row = parent.rows[rowIndex]
    if row.action and row.action.type == "openMenu" and row.action.menu == childId then
      return position
    end
  end
end

function Runtime:switchMenu(currentMenu, targetId)
  local target = self.menus[targetId]

  assert(target, "Gearbox: action references missing menu: " .. targetId)

  -- Going back to parent: parent should land on the child we are leaving.
  if currentMenu.parentId == targetId then
    local pos = navigablePositionForChild(target, currentMenu.id)
    if pos then target.returnPosition = pos end
  end

  currentMenu.modal:exit()
  target.modal:enter()
end

--- Start session input observation and enter the requested menu (default: root).
---@param targetId? string
---@return boolean
function Runtime:beginMenuSession(targetId)
  if hs.eventtap.isSecureInputEnabled() then
    hs.alert.show("Gearbox cannot capture keys while Secure Input is active")
    return false
  end

  self.sessionInputTap:start()

  if not self.sessionInputTap:isEnabled() then
    self.sessionInputTap:stop()
    hs.alert.show("Gearbox could not start session input observation")
    return false
  end

  local target = self.menus[targetId or self.rootId]
  -- Restore leader selector across invocations (close → reopen). In-memory
  -- returnPosition already handles Back/Esc; this hydrates it after reload.
  if target.id == self.rootId and not target.returnPosition then
    local ok, saved = pcall(function() return hs.settings.get("Gearbox.ui.leaderPosition") end)
    if ok and type(saved) == "number" and saved >= 1 and saved <= #target.navigableRows then
      target.returnPosition = saved
    end
  end
  target.modal:enter()
  return true
end

--- End the active Gearbox menu session and stop input observation.
function Runtime:endMenuSession()
  if self.sessionInputTap then self.sessionInputTap:stop() end

  if self.activeMenu then self.activeMenu.modal:exit() end
end

--- Dispatch one session input event without consuming modifier changes.
---@param event any
---@return boolean|nil
function Runtime:handleSessionInput(event)
  -- Hammerspoon reports modifier and status-key transitions as `flagsChanged`.
  if event:getType() == hs.eventtap.event.types.flagsChanged then
    if event:getKeyCode() == hs.keycodes.map.capslock then
      local rootMenu = self.menus[self.rootId]

      if self.activeMenu == rootMenu then
        self.hud:refresh(rootMenu, self:checkedRows(rootMenu))
      end
    end

    -- Observed modifier events must continue to macOS unchanged.
    return nil
  end

  return self:handleCharacterKeyDown(event)
end

--- Handle one key-down event while a Gearbox menu session is active.
---@param event any
---@return boolean|nil
function Runtime:handleCharacterKeyDown(event)
  local menu = self.activeMenu

  -- Until Caps Lock is released, its tap owns letters. This prevents the f
  -- opening Finder Folders from also selecting the menu's Home row.
  if not menu or (self.capsLockTap and self.capsLockTap:isEnabled()) then
    return nil
  end

  local flags = event:getFlags()

  if not hasNoCharacterCommandModifiers(flags) and
      not matchesCharacterCommandModifiers(
        flags, self.requiredHotkeyModifiers) then
    return nil
  end

  if event:getKeyCode() == self.globalHotkeyKeyCode and
      includesRequiredHotkeyModifiers(flags,
        self.requiredHotkeyModifiers) then
    return nil
  end

  local character = activationCharacterForEvent(event)

  if not character then return nil end

  -- Hyper letters belong to global shortcuts, including those owned by other apps.
  if flags.ctrl and flags.alt and flags.cmd and flags.shift and
      hasQuickLaunch(self.config) and character:match("^[A-Za-z]$") then
    return nil
  end

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
  local previousTimeout = self.config.menu.timeout
  -- Remember where we are before leaving: when we return via Esc/Back
  -- we restore the parent on the entry we just activated. For leader we
  -- also persist across invocations (hs.settings) so close→reopen lands
  -- on last activated row. Submenus remember last drift/activation except
  -- footer (Esc) — otherwise re-enter would highlight Back instead of last item.
  local pos = navigablePositionForRow(menu, row)
  if pos then
    if menu.id == self.rootId then
      menu.returnPosition = pos
      pcall(function() hs.settings.set("Gearbox.ui.leaderPosition", pos) end)
    elseif row.action and row.action.type == "openMenu" and row.kind ~= "footer" then
      menu.returnPosition = pos
    end
  end
  local result = self.actions.execute(row.action, {
    openMenu = function(targetId) self:switchMenu(menu, targetId) end,
    exit = function() self:endMenuSession() end,
    setTheme = function(selection) self.theme:select(selection) end,
    setMatchingTheme = function(id) self.theme:setMatchingTheme(id) end,
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
  end

  if self.config.menu.timeout ~= previousTimeout or
      (result.refresh and self.config.navigation.resetTimeoutOnInput) then
    self:resetTimeout(menu)
  end

  if result.close then
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

  -- Drift is life: every ↑↓ updates returnPosition so Back/Esc → re-enter
  -- lands on last highlighted row, not Esc footer. Only leader is persisted
  -- via hs.settings (submenus stay in-memory for the session).
  if menu.selectedPosition then
    menu.returnPosition = menu.selectedPosition
    if menu.id == self.rootId then
      pcall(function() hs.settings.set("Gearbox.ui.leaderPosition", menu.selectedPosition) end)
    end
  end

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
    if not row.divider and not row.header then
      local callback = function() self:runAction(menu, row) end

      -- Character rows are dispatched by the eventtap, not the modal.
      -- Rows without a key are arrow/return only.
      if row.key ~= nil then
        if row.kind == "footer" then
          self:bindBare(menu.modal, row.key, callback)
        elseif not isCharacterActivationKey(row.key) then
          self:bindFlexible(menu.modal, row.key, callback)
        end
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
    -- Restore last position when returning via Back/Esc; otherwise fallback to first row.
    -- Ensures leader + every submenu open with a highlight (no empty state).
    if menu.returnPosition and menu.returnPosition >= 1 and menu.returnPosition <= #menu.navigableRows then
      menu.selectedPosition = menu.returnPosition
      menu.selectedIndex = menu.navigableRows[menu.selectedPosition]
    elseif #menu.navigableRows > 0 then
      menu.selectedPosition = 1
      menu.selectedIndex = menu.navigableRows[1]
    else
      menu.selectedIndex = nil
      menu.selectedPosition = nil
    end

    self.theme:refreshAppearance()
    self.preferences:refreshMenu(menu)
    -- Scratchpad label reflects warm-up state: slow first launch → ready.
    if menu.id == self.rootId and self.scratchpad then
      for _, row in ipairs(menu.rows) do
        if row.action and row.action.type == "openScratchpad" then
          row.label = self.scratchpad:menuLabel()
          break
        end
      end
    end
    self.hud:show(menu, self:checkedRows(menu))
    if menu.selectedPosition then self.hud:select(menu) end
    self:resetTimeout(menu)
  end

  menu.modal.exited = function()
    if self.activeMenu == menu then self.activeMenu = nil end

    -- Keep returnPosition for the next Back/Esc into this menu; clear live selection.
    menu.selectedIndex = nil
    menu.selectedPosition = nil

    self.hud:close()
    self:clearTimeout()
  end
end

--- Activate an app name or an already-validated openMenu target.
-- Both four-modifier Hyper and the Caps Lock handler enter here.
-- Menu targets retain the session; app launches close it before switching focus.
function Runtime:dispatchQuickLaunch(target)
  if type(target) == "string" then
    if self.activeMenu then self:endMenuSession() end
    self.actions.execute({ type = "launchApp", name = target })
  elseif target and target.type == "openMenu" then
    if not self.activeMenu then
      self:beginMenuSession(target.menu)
    elseif self.activeMenu.id ~= target.menu then
      self:switchMenu(self.activeMenu, target.menu)
    end
  elseif target and target.type == "openSiri" then
    if self.activeMenu then self:endMenuSession() end
    self.actions.execute({ type = "openSiri" })
  elseif type(target) == "table" and target.name then
    if self.activeMenu then self:endMenuSession() end
    self.actions.execute({ type = "launchApp", name = target.name, bundleID = target.bundleID })
  end
end

--- F18 supplies a physical down/up pair after macOS remaps Caps Lock.
--- Only observe other keys while it is held. Modifier changes also cancel a tap.
function Runtime:bindCapsLock()
  local events = hs.eventtap.event
  -- F18 is a held key, not a modifier. Only an unused down/up pair toggles
  -- capitalization; any intervening key or modifier makes this a chord.
  local used = false
  local tap = hs.eventtap.new({ events.types.keyDown, events.types.flagsChanged }, function(event)
    if event:getType() == events.types.flagsChanged then
      used = true
      return nil
    end
    local code = event:getKeyCode()
    if code == hs.keycodes.map.f18 then return nil end
    used = true
    -- Resolve by physical letter even when capitalization is already on.
    -- Once the chord is released, menu rows resume their usual case rules.
    local flags = event:getFlags()
    if flags.cmd or flags.ctrl or flags.alt or flags.shift then return nil end
    local target = quickLaunchTarget(self.config, hs.keycodes.map[code])
    if not target then return nil end
    if event:getProperty(events.properties.keyboardEventAutorepeat) == 0 then
      self:dispatchQuickLaunch(target)
    end
    return true
  end)
  assert(tap, "Gearbox: could not create Caps Lock input tap")
  self.capsLockTap = tap
  local binding = hs.hotkey.bind({}, "f18", function()
    used = false
    if hs.eventtap.isSecureInputEnabled() then return end
    tap:start()
    if not tap:isEnabled() then hs.alert.show("Gearbox could not capture Caps Lock") end
  end, function()
    local toggle = tap:isEnabled() and not used and not hs.eventtap.isSecureInputEnabled()
    tap:stop()
    if toggle then
      hs.hid.capslock.toggle()
      if self.activeMenu == self.menus[self.rootId] then
        self.hud:refresh(self.activeMenu, self:checkedRows(self.activeMenu))
      end
    end
  end)
  assert(binding, "Gearbox: failed to register F18 for Caps Lock")
  table.insert(self.quickLaunchHotkeys, binding)
end

--- Delete the global hotkey and all modal bindings.
function Runtime:deleteBindings()
  if self.capsLockTap then self.capsLockTap:stop() end
  if self.sessionInputTap then
    self.sessionInputTap:stop()
    self.sessionInputTap = nil
  end

  for _, binding in ipairs(self.quickLaunchHotkeys) do binding:delete() end
  self.quickLaunchHotkeys = {}

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

    self.sessionInputTap = hs.eventtap.new({
      hs.eventtap.event.types.keyDown,
      hs.eventtap.event.types.flagsChanged
    }, function(event)
      return self:handleSessionInput(event)
    end)

    if not self.sessionInputTap then
      error("Gearbox: failed to create the session input tap", 0)
    end

    for _, menu in pairs(self.menus) do self:registerMenu(menu) end

    self.globalHotkey = hs.hotkey.bind(self.config.hotkey.modifiers,
      self.config.hotkey.key, function()
        if self.activeMenu then
          self:endMenuSession()
        elseif self.scratchpad and self.scratchpad:isVisible() then
          self.scratchpad:hide()
        else
          self:beginMenuSession()
        end
      end)

    if not self.globalHotkey then
      error("Gearbox: failed to register the global hotkey", 0)
    end

    local hyper = { "ctrl", "alt", "cmd", "shift" }
    local toggle = self.requiredHotkeyModifiers
    for _, key in ipairs(self.menus[self.rootId].quickLaunchKeys) do
      if toggle.ctrl and toggle.alt and toggle.cmd and toggle.shift and
          resolveHotkeyKeyCode(key) == self.globalHotkeyKeyCode then
        error("Gearbox: Hyper+" .. key .. " is also the menu hotkey", 0)
      end
      local target = quickLaunchTarget(self.config, key)
      local binding = hs.hotkey.bind(hyper, key, function()
        self:dispatchQuickLaunch(target)
      end)
      assert(binding, "Gearbox: failed to register Hyper+" .. key)
      table.insert(self.quickLaunchHotkeys, binding)
    end

    if self.config.capsLockViaF18 then self:bindCapsLock() end
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
