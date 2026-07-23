local Runtime = {}
Runtime.__index = Runtime

local function keyIdentity(key)
  if key:match("^#%d+$") then
    return "#" .. tonumber(key:sub(2))
  end

  return key:lower()
end

function Runtime.new(config, menus, rootId, actions, theme, hud, scratchpad)
  local self = setmetatable({}, Runtime)

  self.config = config
  self.menus = menus
  self.rootId = rootId
  self.actions = actions
  self.theme = theme
  self.hud = hud
  self.scratchpad = scratchpad

  self.activeMenu = nil
  self.timeoutTimer = nil
  self.globalHotkey = nil
  self.started = false

  return self
end

function Runtime:clearTimeout()
  if self.timeoutTimer then
    self.timeoutTimer:stop()
    self.timeoutTimer = nil
  end
end

function Runtime:resetTimeout(menu)
  self:clearTimeout()

  if self.config.menu.timeout <= 0 then
    return
  end

  self.timeoutTimer = hs.timer.doAfter(
    self.config.menu.timeout,
    function()
      if self.activeMenu == menu then
        menu.modal:exit()
        hs.alert.show("Gearbox Cleared", 0.5)
      end
    end
  )
end

function Runtime:bindBare(modal, key, callback)
  modal:bind({}, key, callback)
end

function Runtime:bindFlexible(modal, key, callback)
  self:bindBare(modal, key, callback)

  -- Preserve the global toggle when a menu key matches its unmodified key.
  if keyIdentity(key) ~= keyIdentity(self.config.hotkey.key) then
    modal:bind(self.config.hotkey.modifiers, key, callback)
  end
end

function Runtime:bindRepeating(modal, key, callback)
  -- Hammerspoon's message-less overload expects pressedfn in position three.
  modal:bind({}, key, callback, nil, callback)
end

function Runtime:checkedRows(menu)
  local checked = {}
  local caffeinateMode

  for index, row in ipairs(menu.rows) do
    if not row.divider and row.checkable then
      if row.action.type == "setCaffeinateMode" then
        caffeinateMode =
            caffeinateMode or self.actions.currentCaffeinateMode()

        checked[index] = row.action.mode == caffeinateMode
      elseif row.action.type == "setTheme" then
        checked[index] = self.theme:isSelected(row.action.theme)
      end
    end
  end

  return checked
end

function Runtime:openMenu(currentMenu, targetId)
  local target = self.menus[targetId]

  assert(target, "Gearbox: action references missing menu: " .. targetId)

  currentMenu.modal:exit()
  target.modal:enter()
end

function Runtime:runAction(menu, row)
  local result = self.actions.execute(row.action, {
    openMenu = function(targetId)
      self:openMenu(menu, targetId)
    end,
    exit = function()
      menu.modal:exit()
    end,
    setTheme = function(selection)
      self.theme:select(selection)
    end,
    openScratchpad = function()
      assert(self.scratchpad, "Gearbox: scratchpad is disabled")
      menu.modal:exit()
      self.scratchpad:show()
    end,
  })

  if result.handled then
    return
  end

  if result.refresh then
    self.hud:refresh(menu, self:checkedRows(menu))

    if self.config.navigation.resetTimeoutOnInput then
      self:resetTimeout(menu)
    end
  elseif result.close then
    menu.modal:exit()
  end
end

function Runtime:moveSelection(menu, direction)
  local count = #menu.navigableRows

  if count == 0 then
    return
  end

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

function Runtime:activateSelection(menu)
  if not menu.selectedIndex then
    return
  end

  local row = menu.rows[menu.selectedIndex]

  if row and row.action then
    self:runAction(menu, row)
  end
end

function Runtime:registerMenu(menu)
  menu.navigableRows = {}

  for index, row in ipairs(menu.rows) do
    if not row.divider then
      local callback = function()
        self:runAction(menu, row)
      end

      if row.kind == "footer" then
        self:bindBare(menu.modal, row.key, callback)
      else
        self:bindFlexible(menu.modal, row.key, callback)
      end

      if row.kind ~= "footer"
          or self.config.navigation.includeFooter then
        table.insert(menu.navigableRows, index)
      end
    end
  end

  if self.config.navigation.enabled then
    self:bindRepeating(menu.modal, "up", function()
      self:moveSelection(menu, -1)
    end)

    self:bindRepeating(menu.modal, "down", function()
      self:moveSelection(menu, 1)
    end)

    self:bindBare(
      menu.modal,
      self.config.navigation.activateKey,
      function()
        self:activateSelection(menu)
      end
    )
  end

  menu.modal.entered = function()
    self.activeMenu = menu
    menu.selectedIndex = nil
    menu.selectedPosition = nil

    self.theme:refreshAppearance()
    self.hud:show(menu, self:checkedRows(menu))
    self:resetTimeout(menu)
  end

  menu.modal.exited = function()
    if self.activeMenu == menu then
      self.activeMenu = nil
    end

    menu.selectedIndex = nil
    menu.selectedPosition = nil

    self.hud:close()
    self:clearTimeout()
  end
end

function Runtime:deleteBindings()
  if self.globalHotkey then
    self.globalHotkey:delete()
    self.globalHotkey = nil
  end

  for _, menu in pairs(self.menus) do
    menu.modal:delete()
  end
end

function Runtime:start()
  if self.started then
    return self
  end

  local started, startError = xpcall(function()
    for _, menu in pairs(self.menus) do
      self:registerMenu(menu)
    end

    self.globalHotkey = hs.hotkey.bind(
      self.config.hotkey.modifiers,
      self.config.hotkey.key,
      function()
        if self.scratchpad and self.scratchpad:isVisible() then
          self.scratchpad:hide()
        elseif self.activeMenu then
          self.activeMenu.modal:exit()
        else
          self.menus[self.rootId].modal:enter()
        end
      end
    )

    if not self.globalHotkey then
      error("Gearbox: failed to register the global hotkey", 0)
    end

    self.theme:activate()

    if self.scratchpad then
      self.scratchpad:prepare()
    end
  end, debug.traceback)

  if not started then
    if self.scratchpad then
      self.scratchpad:delete()
    end

    self:deleteBindings()
    error(startError, 0)
  end

  self.started = true
  return self
end

function Runtime:stop()
  if not self.started then
    return
  end

  if self.activeMenu then
    self.activeMenu.modal:exit()
  end

  self:clearTimeout()
  self.hud:close()

  if self.scratchpad then
    self.scratchpad:delete()
  end

  self:deleteBindings()

  self.started = false
end

return Runtime
