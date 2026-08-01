--- Pure button focus and activation state machine.
local namespace = (...):match("^(.*)%.button_group$")
local Validation = require(namespace .. ".validation")
local Button = require(namespace .. ".button")
local ButtonGroup = {}
ButtonGroup.__index = ButtonGroup

function ButtonGroup.new(buttons)
    Validation.array(buttons, "buttons")
    local self = setmetatable({buttons = {}, byId = {}, byHotkey = {}, focusedId = nil, hoveredId = nil, armedId = nil, pressSource = nil, closed = false, defaultId = nil}, ButtonGroup)
    for index, button in ipairs(buttons) do
        Button.validate(button, "buttons[" .. index .. "]")
        if self.byId[button.id] then Validation.fail("duplicate button id: " .. button.id, 2) end
        local hotkey = button.hotkey:lower()
        if self.byHotkey[hotkey] then Validation.fail("duplicate button hotkey: " .. button.hotkey, 2) end
        if button.default and self.defaultId then Validation.fail("multiple default buttons", 2) end
        local copied = Validation.copy(button)
        self.byId[copied.id], self.byHotkey[hotkey] = copied, copied.id
        if copied.default then self.defaultId = copied.id end
        table.insert(self.buttons, copied)
    end
    if #self.buttons == 0 then Validation.fail("buttons cannot be empty", 2) end
    return self
end

function ButtonGroup:reset()
    self.focusedId, self.hoveredId, self.armedId, self.pressSource = nil, nil, nil, nil
end

function ButtonGroup:close() self:reset(); self.closed = true end

function ButtonGroup:focus(id)
    if self.closed or not self.byId[id] or not self.byId[id].enabled then return false end
    self.focusedId = id
    return true
end

function ButtonGroup:focusRelative(direction)
    if self.closed then return false end
    if direction ~= 1 and direction ~= -1 then
        Validation.fail("focus direction must be 1 or -1", 2)
    end
    local enabled = {}
    for _, button in ipairs(self.buttons) do if button.enabled then table.insert(enabled, button.id) end end
    if #enabled == 0 then return false end
    local position = 0
    for index, id in ipairs(enabled) do if id == self.focusedId then position = index end end
    position = ((position - 1 + direction) % #enabled) + 1
    self.focusedId = enabled[position]
    return true
end

function ButtonGroup:default()
    if self.defaultId and self.byId[self.defaultId].enabled then return self.defaultId end
end

function ButtonGroup:mnemonic(key)
    return type(key) == "string" and self.byHotkey[key:lower()] or nil
end

function ButtonGroup:hover(id, active)
    if self.closed or not self.byId[id] then return false end
    if active then self.hoveredId = id elseif self.hoveredId == id then self.hoveredId = nil end
    return true
end

function ButtonGroup:arm(id, source)
    if self.closed or (source ~= "keyboard" and source ~= "mouse") then return false end
    local button = self.byId[id]
    if not button or not button.enabled or self.armedId then return false end
    self.focusedId, self.armedId, self.pressSource = id, id, source
    return true
end

function ButtonGroup:cancel(id, source)
    if self.armedId == id and self.pressSource == source then self.armedId, self.pressSource = nil, nil; return true end
    return false
end

function ButtonGroup:activate(id, source)
    if self.closed or self.armedId ~= id or self.pressSource ~= source then return nil end
    self.armedId, self.pressSource = nil, nil
    return {id = id, source = source}
end

return ButtonGroup
