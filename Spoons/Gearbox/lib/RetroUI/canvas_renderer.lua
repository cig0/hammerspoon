--- Hammerspoon canvas conversion for RetroUI dialog models.
local namespace = (...):match("^(.*)%.canvas_renderer$")
local Button = require(namespace .. ".button")
local Renderer = {}
Renderer.__index = Renderer

local function style(font, color, alignment)
    return {font = font, color = color, paragraphStyle = {alignment = alignment or "left", lineBreak = "clip"}}
end

local function pointPadding(value) return value.top + value.bottom, value.left + value.right end

function Renderer.new(spec, theme, frame, group)
    local self = setmetatable({spec = spec, theme = theme, frame = frame, group = group, canvas = nil, buttonElements = {}}, Renderer)
    self.font = {name = theme.typography.family, size = theme.typography.bodySize}
    local fontInfo = hs.styledtext.fontInfo(self.font)
    if not fontInfo or not fontInfo.fixedPitch or
        type(fontInfo.maximumAdvancement) ~= "table" or
        type(fontInfo.maximumAdvancement.w) ~= "number" or
        type(fontInfo.ascender) ~= "number" or
        type(fontInfo.descender) ~= "number" or
        type(fontInfo.leading) ~= "number" then
        error("RetroUI: theme.typography.family must resolve to a fixed-pitch font", 2)
    end
    self.fonts = {
        regular = self.font,
        bold = hs.styledtext.convertFont(self.font, true)
    }
    self.charWidth = math.ceil(fontInfo.maximumAdvancement.w)
    self.lineHeight = math.ceil(fontInfo.ascender - fontInfo.descender +
                                    fontInfo.leading)
    if self.charWidth <= 0 or self.lineHeight <= 0 then
        error("RetroUI: configured font has invalid metrics", 2)
    end
    local vertical, horizontal = pointPadding(theme.dialog.outerPadding)
    self.buttonExtentX = math.max(theme.button.shadowOffset.x,
                                  theme.button.pressOffset.x)
    self.buttonExtentY = math.max(theme.button.shadowOffset.y,
                                  theme.button.pressOffset.y)
    self.buttonLayouts = {}
    self.footer = spec.footer
    self.footerButton = self.footer and group.byId[self.footer.buttonId] or nil
    self.standardButtons = {}
    self.buttonRowWidth = 0
    for _, button in ipairs(group.buttons) do
        local width = self.charWidth * #button.label +
                          theme.button.padding.left +
                          theme.button.padding.right
        self.buttonLayouts[button.id] = {w = width}
        if button.id ~= (self.footer and self.footer.buttonId) then
            table.insert(self.standardButtons, button)
        end
    end
    for index, button in ipairs(self.standardButtons) do
        if index > 1 then self.buttonRowWidth = self.buttonRowWidth + theme.button.gap end
        self.buttonRowWidth = self.buttonRowWidth + self.buttonLayouts[button.id].w
    end
    self.footerTextWidth = self.footer and self.charWidth * #self.footer.text or 0
    self.footerWidth = self.footer and
                           self.footerTextWidth + theme.button.gap +
                               self.buttonLayouts[self.footer.buttonId].w +
                               self.buttonExtentX or 0
    self.contentWidth = math.max(frame.columns * self.charWidth,
                                 self.buttonRowWidth +
                                     self.buttonExtentX, self.footerWidth)
    self.width = self.contentWidth + horizontal
    self.frameHeight = frame.rows * self.lineHeight
    self.buttonHeight = self.lineHeight + theme.button.padding.top +
                            theme.button.padding.bottom
    local nextY = theme.dialog.outerPadding.top + self.frameHeight
    if self.footer then
        self.footerY = nextY + theme.button.gap
        self.footerTextY = self.footerY +
                               math.floor((self.buttonHeight - self.lineHeight) / 2)
        local layout = self.buttonLayouts[self.footer.buttonId]
        layout.x = theme.dialog.outerPadding.left + self.footerTextWidth +
                       theme.button.gap
        layout.y, layout.h = self.footerY, self.buttonHeight
        nextY = self.footerY + self.buttonHeight + self.buttonExtentY
    end
    if #self.standardButtons > 0 then
        self.buttonY = nextY + theme.button.gap
        local x = theme.dialog.outerPadding.left +
                      (self.contentWidth - self.buttonRowWidth -
                          self.buttonExtentX) / 2
        for _, button in ipairs(self.standardButtons) do
            local layout = self.buttonLayouts[button.id]
            layout.x, layout.y, layout.h = x, self.buttonY, self.buttonHeight
            x = x + layout.w + theme.button.gap
        end
        nextY = self.buttonY + self.buttonHeight + self.buttonExtentY
    end
    self.height = nextY + theme.dialog.outerPadding.bottom
    for _, button in ipairs(group.buttons) do
        local layout = self.buttonLayouts[button.id]
        assert(layout.x and layout.y and layout.h,
               "RetroUI: button layout was not assigned")
    end
    return self
end

function Renderer:roleColor(role)
    local dialog = self.theme.dialog
    if role == "title" then return dialog.titleTextColor end
    if role == "notice" then return dialog.noticeTextColor end
    if role == "hotkey" then return dialog.hotkeyTextColor end
    if role == "frame" then return self.theme.frame.borderColor end
    return dialog.bodyTextColor
end

function Renderer:roleWeight(role)
    if role == "title" then return self.theme.typography.titleWeight end
    if role == "notice" then return self.theme.typography.noticeWeight end
    return self.theme.typography.bodyWeight
end

function Renderer:frameText()
    local result = nil
    for lineIndex, line in ipairs(self.frame.lines) do
        for _, item in ipairs(line.runs) do
            local value = hs.styledtext.new(item.text, style(self.fonts[self:roleWeight(item.role)], self:roleColor(item.role), "left"))
            result = result and result .. value or value
        end
        if lineIndex < #self.frame.lines then
            local newline = hs.styledtext.new("\n", style(self.fonts[self.theme.typography.bodyWeight], self.theme.dialog.bodyTextColor, "left"))
            result = result and result .. newline or newline
        end
    end
    return result
end

function Renderer:footerText()
    return hs.styledtext.new(self.footer.text,
                             style(self.fonts[self:roleWeight(self.footer.role)],
                                   self:roleColor(self.footer.role), "left"))
end

function Renderer:buttonFrame(button, pressed)
    local layout = self.buttonLayouts[button.id]
    local offset = pressed and self.theme.button.pressOffset or {x = 0, y = 0}
    return {x = layout.x + offset.x, y = layout.y + offset.y, w = layout.w, h = layout.h}
end

function Renderer:buttonLabel(button, colors)
    local start = assert(button.label:lower():find(button.hotkey:lower(), 1, true))
    local finish = start + #button.hotkey - 1
    local result
    local function append(text, color)
        if text == "" then return end
        local value = hs.styledtext.new(text,
                                        style(self.fonts[self.theme.typography.buttonWeight],
                                              color, "center"))
        result = result and result .. value or value
    end
    append(button.label:sub(1, start - 1), colors.textColor)
    append(button.label:sub(start, finish), colors.hotkeyColor)
    append(button.label:sub(finish + 1), colors.textColor)
    return result
end

function Renderer:elements()
    local elements = {{type = "rectangle", action = "fill", frame = {x = 0, y = 0, w = self.width, h = self.height}, fillColor = self.theme.dialog.backgroundColor}}
    table.insert(elements, {type = "text", frame = {x = self.theme.dialog.outerPadding.left, y = self.theme.dialog.outerPadding.top, w = self.width - self.theme.dialog.outerPadding.left - self.theme.dialog.outerPadding.right, h = self.frameHeight}, text = self:frameText()})
    if self.footer then
        table.insert(elements, {id = "retro-ui:footer:text", type = "text", frame = {x = self.theme.dialog.outerPadding.left, y = self.footerTextY, w = self.footerTextWidth, h = self.lineHeight}, text = self:footerText()})
    end
    self.buttonElements = {}
    for _, button in ipairs(self.group.buttons) do
        local state = Button.state(button.id, self.group)
        local colors = self.theme.button[state]
        local pressed = state == "pressed"
        local frame = self:buttonFrame(button, pressed)
        local layout = self.buttonLayouts[button.id]
        local shadowId, faceId, labelId, hitId = "retro-ui:button:" .. button.id .. ":shadow", "retro-ui:button:" .. button.id .. ":face", "retro-ui:button:" .. button.id .. ":label", "retro-ui:button:" .. button.id .. ":hit"
        table.insert(elements, {id = shadowId, type = "rectangle", action = "fill", frame = {x = layout.x + self.theme.button.shadowOffset.x, y = layout.y + self.theme.button.shadowOffset.y, w = layout.w, h = layout.h}, fillColor = self.theme.button.shadowColor})
        local faceIndex = #elements + 1
        table.insert(elements, {id = faceId, type = "rectangle", action = "fill", frame = frame, fillColor = colors.faceColor})
        local labelIndex = #elements + 1
        table.insert(elements, {id = labelId, type = "text", frame = {x = frame.x, y = frame.y + self.theme.button.padding.top, w = frame.w, h = self.lineHeight}, text = self:buttonLabel(button, colors)})
        table.insert(elements, {id = hitId, type = "rectangle", action = "fill", frame = {x = layout.x, y = layout.y, w = layout.w + self.buttonExtentX, h = layout.h + self.buttonExtentY}, fillColor = {white = 1, alpha = 0.001}, trackMouseByBounds = true, trackMouseDown = true, trackMouseUp = true, trackMouseEnterExit = true})
        self.buttonElements[button.id] = {faceIndex = faceIndex, labelIndex = labelIndex, state = state}
    end
    return elements
end

function Renderer:show(screen)
    local frame = screen:frame()
    if self.width > frame.w or self.height > frame.h then
        error("RetroUI: dialog exceeds the selected screen", 2)
    end
    self.canvas = assert(hs.canvas.new({x = frame.x + (frame.w - self.width) / 2, y = frame.y + (frame.h - self.height) / 2, w = self.width, h = self.height}), "RetroUI: cannot create dialog canvas")
    self.canvas:replaceElements(self:elements())
    self.canvas:wantsLayer(true)
    self.canvas:level(hs.canvas.windowLevels.floating)
    self.canvas:clickActivating(false)
    if self.spec.dismissOnBackgroundClick then
        self.canvas:canvasMouseEvents(true, true, false, false)
    end
    self.canvas:show()
    return self.canvas
end

function Renderer:refresh()
    if not self.canvas then return end
    for _, button in ipairs(self.group.buttons) do
        local record = self.buttonElements[button.id]
        local state = Button.state(button.id, self.group)
        if state ~= record.state then
            record.state = state
            local colors = self.theme.button[state]
            local frame = self:buttonFrame(button, state == "pressed")
            self.canvas:elementAttribute(record.faceIndex, "frame", frame)
            self.canvas:elementAttribute(record.faceIndex, "fillColor",
                                         colors.faceColor)
            self.canvas:elementAttribute(record.labelIndex, "frame", {
                x = frame.x,
                y = frame.y + self.theme.button.padding.top,
                w = frame.w,
                h = self.lineHeight
            })
            self.canvas:elementAttribute(record.labelIndex, "text",
                                         self:buttonLabel(button, colors))
        end
    end
end

function Renderer:delete()
    if not self.canvas then return end
    local canvas = self.canvas
    self.canvas = nil
    local firstError
    local ok, err = pcall(function() canvas:mouseCallback(nil) end)
    if not ok then firstError = err end
    ok, err = pcall(function() canvas:delete() end)
    if not ok and not firstError then firstError = err end
    if firstError then error(firstError, 0) end
end

return Renderer
