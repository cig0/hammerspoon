--- Interactive themed RetroUI dialog.
local namespace = (...):match("^(.*)%.dialog$")
local Validation = require(namespace .. ".validation")
local Frame = require(namespace .. ".frame")
local Theme = require(namespace .. ".theme")
local ButtonGroup = require(namespace .. ".button_group")
local Renderer = require(namespace .. ".canvas_renderer")
local Dialog = {}
Dialog.__index = Dialog

local allowed = {theme = true, themeOverrides = true, title = true, titleAlignment = true, frameStyle = true, padding = true, content = true, footer = true, buttons = true, dismissAfter = true, dismissOnEscape = true, dismissOnBackgroundClick = true, onDismiss = true}
local dismissalReasons = {button = true, timeout = true, programmatic = true}

local function normalizeSpec(spec)
    Validation.type(spec, "table", "dialog")
    Validation.exactKeys(spec, allowed, "dialog")
    local normalized = Validation.copy(spec)
    if normalized.themeOverrides == nil then normalized.themeOverrides = {} end
    if normalized.dismissOnEscape == nil then normalized.dismissOnEscape = false end
    if normalized.dismissOnBackgroundClick == nil then
        normalized.dismissOnBackgroundClick = false
    end
    if normalized.onDismiss == nil then normalized.onDismiss = function() end end
    return normalized
end

local function validateSpec(spec)
    Validation.type(spec.theme, "string", "dialog.theme")
    Validation.type(spec.title, "string", "dialog.title")
    if spec.titleAlignment ~= nil then
        Validation.enum(spec.titleAlignment,
                        {left = true, center = true, right = true},
                        "dialog.titleAlignment")
    end
    if spec.frameStyle ~= nil then Validation.enum(spec.frameStyle, {single = true, double = true}, "dialog.frameStyle") end
    if spec.padding ~= nil then
        Validation.type(spec.padding, "table", "dialog.padding")
        Validation.exactKeys(spec.padding, {top = true, right = true, bottom = true, left = true}, "dialog.padding")
        for _, side in ipairs({"top", "right", "bottom", "left"}) do Validation.nonNegativeInteger(spec.padding[side], "dialog.padding." .. side) end
    end
    Validation.type(spec.content, "table", "dialog.content")
    if spec.footer ~= nil then
        Validation.type(spec.footer, "table", "dialog.footer")
        Validation.exactKeys(spec.footer,
                             {text = true, role = true, buttonId = true},
                             "dialog.footer")
        Validation.type(spec.footer.text, "string", "dialog.footer.text")
        Validation.type(spec.footer.role, "string", "dialog.footer.role")
        Validation.type(spec.footer.buttonId, "string",
                        "dialog.footer.buttonId")
        if spec.footer.role == "" then
            Validation.fail("dialog.footer.role cannot be empty", 2)
        end
    end
    Validation.type(spec.buttons, "table", "dialog.buttons")
    Validation.type(spec.dismissOnEscape, "boolean", "dialog.dismissOnEscape")
    Validation.type(spec.dismissOnBackgroundClick, "boolean", "dialog.dismissOnBackgroundClick")
    Validation.type(spec.onDismiss, "function", "dialog.onDismiss")
    if spec.dismissAfter ~= nil then Validation.positiveNumber(spec.dismissAfter, "dialog.dismissAfter") end
end

function Dialog.show(spec)
    spec = normalizeSpec(spec)
    validateSpec(spec)
    local theme = Theme.resolve(spec.theme, spec.themeOverrides)
    local group = ButtonGroup.new(spec.buttons)
    if spec.footer and not group.byId[spec.footer.buttonId] then
        Validation.fail("dialog.footer.buttonId must name a button", 2)
    end
    local frame = Frame.render({style = spec.frameStyle or theme.frame.style, title = {text = spec.title, alignment = spec.titleAlignment or theme.frame.titleAlignment}, padding = spec.padding or theme.frame.padding, rows = spec.content})
    local self = setmetatable({spec = spec, theme = theme, group = group, frame = frame, renderer = nil, modal = nil, timeoutTimer = nil, releaseTimer = nil, backgroundArmed = false, activationPending = false, closing = false, closed = false, dismissReason = nil, dismissedButtonId = nil}, Dialog)
    local started, err = xpcall(function()
        self.renderer = Renderer.new(spec, theme, frame, group)
        local canvas = self.renderer:show(hs.screen.mainScreen())
        canvas:mouseCallback(function(_, message, identifier) self:mouse(message, identifier) end)
        self.modal = hs.hotkey.modal.new()
        self:bindKeys()
        self.modal:enter()
        if spec.dismissAfter then self.timeoutTimer = hs.timer.doAfter(spec.dismissAfter, function() self:dismiss("timeout") end) end
    end, debug.traceback)
    if not started then
        local onDismiss = self.spec.onDismiss
        self.spec.onDismiss = function() end
        local cleaned, cleanupError = pcall(function()
            self:dismiss("programmatic")
        end)
        self.spec.onDismiss = onDismiss
        if not cleaned then
            err = err .. "\nRetroUI cleanup failure: " .. tostring(cleanupError)
        end
        error(err, 0)
    end
    return self
end

function Dialog:isVisible() return not self.closed and self.renderer and self.renderer.canvas ~= nil end

function Dialog:refresh() if self.renderer then self.renderer:refresh() end end

function Dialog:bindPressRelease(key, id)
    self.modal:bind({}, key, function()
        if self.activationPending then return end
        if self.group:arm(id, "keyboard") then self:refresh() end
    end, function()
        if self.activationPending then return end
        local activation = self.group:activate(id, "keyboard")
        if activation then self:activateAfterDelay(activation) else self:refresh() end
    end)
end

function Dialog:bindKeys()
    local default = self.group:default()
    if default then self:bindPressRelease("return", default) end
    for _, button in ipairs(self.group.buttons) do
        self:bindPressRelease(button.hotkey:lower(), button.id)
    end
    self.modal:bind({}, "tab", function()
        if not self.activationPending and self.group:focusRelative(1) then
            self:refresh()
        end
    end)
    self.modal:bind({"shift"}, "tab", function()
        if not self.activationPending and self.group:focusRelative(-1) then
            self:refresh()
        end
    end)
    if self.spec.dismissOnEscape then self.modal:bind({}, "escape", function() self:dismiss("programmatic") end) end
end

function Dialog:activateAfterDelay(activation)
    if self.activationPending then return end
    self.activationPending = true
    self.releaseTimer = hs.timer.doAfter(self.theme.button.releaseDelay, function()
        self.releaseTimer = nil
        self:dismiss("button", activation.id)
    end)
end

function Dialog:buttonId(identifier)
    return type(identifier) == "string" and identifier:match("^retro%-ui:button:(.-):hit$") or nil
end

function Dialog:mouse(message, identifier)
    if self.closed or self.activationPending then return end
    local id = self:buttonId(identifier)
    if not id then
        if identifier ~= "canvas" or not self.spec.dismissOnBackgroundClick then
            return
        end
        if message == "mouseDown" then
            self.backgroundArmed = hs.eventtap.checkMouseButtons().left == true
        elseif message == "mouseUp" then
            local leftIsDown = hs.eventtap.checkMouseButtons().left == true
            local shouldDismiss = self.backgroundArmed and not leftIsDown
            self.backgroundArmed = false
            if self.group.armedId then
                self.group:cancel(self.group.armedId, "mouse")
                self:refresh()
            end
            if shouldDismiss then self:dismiss("programmatic") end
        end
        return
    end
    if message == "mouseEnter" then
        if self.group:hover(id, true) then self:refresh() end
    elseif message == "mouseExit" then
        self.group:hover(id, false)
        self.group:cancel(id, "mouse")
        self:refresh()
    elseif message == "mouseDown" then
        self.backgroundArmed = false
        if hs.eventtap.checkMouseButtons().left and self.group:arm(id, "mouse") then self:refresh() end
    elseif message == "mouseUp" then
        self.backgroundArmed = false
        if hs.eventtap.checkMouseButtons().left then return end
        local activation = self.group:activate(id, "mouse")
        if not activation and self.group.armedId then
            self.group:cancel(self.group.armedId, "mouse")
        end
        if activation then self:activateAfterDelay(activation) else self:refresh() end
    end
end

function Dialog:dismiss(reason, buttonId)
    if self.closed or self.closing then return false end
    Validation.enum(reason, dismissalReasons, "dismissal reason")
    if reason == "button" then
        Validation.type(buttonId, "string", "dismissed button id")
        if not self.group.byId[buttonId] then
            Validation.fail("unknown dismissed button id: " .. buttonId, 2)
        end
    elseif buttonId ~= nil then
        Validation.fail(reason .. " dismissal cannot include a button id", 2)
    end
    self.closing = true
    self.dismissReason, self.dismissedButtonId = reason, buttonId
    local firstError
    local function cleanup(callback)
        local ok, err = pcall(callback)
        if not ok and not firstError then firstError = err end
    end
    local timeoutTimer = self.timeoutTimer
    self.timeoutTimer = nil
    if timeoutTimer then cleanup(function() timeoutTimer:stop() end) end
    local releaseTimer = self.releaseTimer
    self.releaseTimer = nil
    if releaseTimer then cleanup(function() releaseTimer:stop() end) end
    self.activationPending = false
    cleanup(function() self.group:close() end)
    local modal = self.modal
    self.modal = nil
    if modal then cleanup(function() modal:delete() end) end
    if self.renderer then cleanup(function() self.renderer:delete() end) end
    self.closed, self.closing = true, false
    cleanup(function() self.spec.onDismiss(reason, buttonId) end)
    if firstError then error(firstError, 0) end
    return true
end

function Dialog:delete() return self:dismiss("programmatic") end

return Dialog
