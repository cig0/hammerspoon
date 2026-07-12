--- Canvas-based HUD renderer.
--
-- Builds the visual menu with a header, rows, dividers, selection highlight, and
-- optional loupe scaling animation. Input: menu definitions and theme colors
-- from `theme.lua`. Output: an `hs.canvas` shown by `runtime.lua`.
local HUD = {}

---@class HUD
---@field config table
---@field theme table
---@field canvas any
---@field animationTimer any
---@field layout table
HUD.__index = HUD

local verticalPositions = {
  top = 0.25,
  center = 0.50,
  bottom = 0.75,
}

local keyDisplayNames = {
  escape = "esc",
  ["return"] = "↩",
}

--- Round to the nearest integer.
---@param value number
---@return integer
local function round(value)
  return math.floor(value + 0.5)
end

--- Append a canvas element and return its 1-based index.
--
-- The index is later used to update element attributes during the loupe
-- animation.
---@param elements table
---@param element table
---@return integer
local function appendElement(elements, element)
  table.insert(elements, element)
  return #elements
end

--- Create a new HUD instance for the given config and theme.
---@param config table
---@param theme table
---@return HUD
function HUD.new(config, theme)
  local self = setmetatable({}, HUD)

  self.config = config
  self.theme = theme
  self.canvas = nil
  self.animationTimer = nil

  self.layout = {
    horizontalPadding = 28,
    keyGap = 14,
    checkWidth = math.max(22, round(config.font.size + 8)),
    selectionInset = 18,
    animationFPS = 60,
    headerTop = 25,
    headerHeight = math.max(32, round(config.font.titleSize + 12)),
    rowHeight = math.max(30, round(config.font.size + 16)),
    textHeight = math.max(22, round(config.font.size + 8)),
    keyWidth = math.max(36, round(config.font.size * 2.6)),
    keyBackgroundHeight = math.max(23, round(config.font.size + 9)),
    dividerHeight = math.max(17, round(config.font.size + 3)),
    bottomPadding = math.max(16, round(config.font.size + 2)),
  }

  self.layout.contentTop =
      self.layout.headerTop + self.layout.headerHeight

  self.layout.labelX =
      self.layout.horizontalPadding
      + self.layout.keyWidth
      + self.layout.keyGap

  return self
end

--- Stop any running selection animation.
function HUD:stopAnimation()
  if self.animationTimer then
    self.animationTimer:stop()
    self.animationTimer = nil
  end
end

--- Hide and destroy the canvas.
function HUD:close()
  self:stopAnimation()

  if self.canvas then
    self.canvas:delete()
    self.canvas = nil
  end
end

--- Choose the screen that should host the HUD.
---@return any
function HUD:targetScreen()
  if self.config.menu.screen == "mouse" then
    return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  end

  return hs.screen.mainScreen()
end

--- Calculate the total canvas height for `rows`.
---@param rows table
---@return number
function HUD:calculateHeight(rows)
  local height = self.layout.contentTop + self.layout.bottomPadding

  for _, row in ipairs(rows) do
    if row.divider then
      height = height + self.layout.dividerHeight
    else
      height = height + self.layout.rowHeight
    end
  end

  return height
end

--- Return the key string shown for a row.
---@param row table
---@return string
function HUD:displayKey(row)
  return row.displayKey or keyDisplayNames[row.key] or row.key
end

--- Return the menu title, optionally prefixed by its emoji.
---@param menu table
---@return string
function HUD:displayTitle(menu)
  if self.config.menu.showEmojis and menu.emoji ~= "" then
    return menu.emoji .. "  " .. menu.title
  end

  return menu.title
end

--- Render one menu row onto the canvas element list.
--
-- Populates `menu.rowVisuals[rowIndex]` with indices and base geometry needed
-- for later scale updates.
---@param elements table
---@param menu table
---@param row table
---@param rowIndex integer
---@param y number
---@param navigationPosition integer|nil
---@param isChecked boolean
function HUD:appendMenuRow(
    elements,
    menu,
    row,
    rowIndex,
    y,
    navigationPosition,
    isChecked
)
  local layout = self.layout
  local colors = self.theme.colors
  local isGroup = row.kind == "group"
  local isFooter = row.kind == "footer"

  local highlightGroup =
      self.config.menu.highlightGroups
      and menu.highlightGroups
      and isGroup

  local font = isGroup
      and self.theme.fonts.group
      or self.theme.fonts.body

  local labelColor = isFooter
      and colors.secondary
      or colors.primary

  local keyColor = colors.secondary

  if isGroup then
    keyColor = highlightGroup and colors.accentText or colors.accent
  end

  local keyBackgroundY =
      y + (layout.rowHeight - layout.keyBackgroundHeight) / 2

  local textY =
      y + (layout.rowHeight - layout.textHeight) / 2

  local keyBackgroundIndex

  if highlightGroup then
    keyBackgroundIndex = appendElement(elements, {
      type = "rectangle",
      action = "fill",
      frame = {
        x = layout.horizontalPadding,
        y = keyBackgroundY,
        w = layout.keyWidth,
        h = layout.keyBackgroundHeight,
      },
      fillColor = colors.accent,
      roundedRectRadii = {
        xRadius = 5,
        yRadius = 5,
      },
    })
  end

  local keyTextIndex = appendElement(elements, {
    type = "text",
    frame = {
      x = layout.horizontalPadding,
      y = textY,
      w = layout.keyWidth,
      h = layout.textHeight,
    },
    text = self.theme.styledText(
      self:displayKey(row),
      font,
      keyColor,
      "center"
    ),
  })

  local checkTextIndex
  local labelX = layout.labelX

  if menu.hasChecks then
    checkTextIndex = appendElement(elements, {
      type = "text",
      frame = {
        x = layout.labelX,
        y = textY,
        w = layout.checkWidth,
        h = layout.textHeight,
      },
      text = self.theme.styledText(
        isChecked and "✓" or "",
        font,
        colors.accent,
        "center"
      ),
    })

    labelX = labelX + layout.checkWidth
  end

  local labelTextIndex = appendElement(elements, {
    type = "text",
    frame = {
      x = labelX,
      y = textY,
      w = self.config.menu.width
          - labelX
          - layout.horizontalPadding,
      h = layout.textHeight,
    },
    text = self.theme.styledText(
      row.label,
      font,
      labelColor,
      "left"
    ),
  })

  menu.rowVisuals[rowIndex] = {
    baseY = y,
    currentScale = 1,
    navigationPosition = navigationPosition,
    font = font,
    keyColor = keyColor,
    labelColor = labelColor,
    labelX = labelX,
    isChecked = isChecked,
    keyBackgroundIndex = keyBackgroundIndex,
    keyTextIndex = keyTextIndex,
    checkTextIndex = checkTextIndex,
    labelTextIndex = labelTextIndex,
  }
end

--- Build and display the canvas for `menu`.
---@param menu table
---@param checkedRows table
function HUD:show(menu, checkedRows)
  self:close()

  menu.rowVisuals = {}
  menu.selectionY = nil

  local navigationPositionByRow = {}

  for position, rowIndex in ipairs(menu.navigableRows) do
    navigationPositionByRow[rowIndex] = position
  end

  local height = self:calculateHeight(menu.rows)
  local screen = self:targetScreen()

  assert(screen, "Gearbox: no screen is available for the HUD")

  local screenFrame = screen:frame()
  local availableHeight = math.max(0, screenFrame.h - height)

  local posX =
      screenFrame.x + (screenFrame.w - self.config.menu.width) / 2

  local posY =
      screenFrame.y
      + availableHeight * verticalPositions[self.config.menu.position]

  self.canvas = hs.canvas.new({
    x = posX,
    y = posY,
    w = self.config.menu.width,
    h = height,
  })

  local layout = self.layout
  local colors = self.theme.colors
  local elements = {}

  appendElement(elements, {
    type = "rectangle",
    action = "fill",
    fillColor = colors.background,
    roundedRectRadii = {
      xRadius = 16,
      yRadius = 16,
    },
  })

  menu.selectionElementIndex = appendElement(elements, {
    type = "rectangle",
    action = "skip",
    frame = {
      x = layout.selectionInset,
      y = layout.contentTop,
      w = self.config.menu.width - (layout.selectionInset * 2),
      h = layout.rowHeight - 2,
    },
    fillColor = colors.selection,
    roundedRectRadii = {
      xRadius = 8,
      yRadius = 8,
    },
  })

  appendElement(elements, {
    type = "text",
    frame = {
      x = layout.horizontalPadding,
      y = layout.headerTop,
      w = self.config.menu.width - (layout.horizontalPadding * 2),
      h = layout.headerHeight,
    },
    text = self.theme.styledText(
      self:displayTitle(menu),
      self.theme.fonts.title,
      colors.primary,
      "left"
    ),
  })

  local y = layout.contentTop

  for rowIndex, row in ipairs(menu.rows) do
    if row.divider then
      appendElement(elements, {
        type = "segments",
        action = "stroke",
        coordinates = {
          {
            x = layout.horizontalPadding,
            y = y + layout.dividerHeight / 2,
          },
          {
            x = self.config.menu.width - layout.horizontalPadding,
            y = y + layout.dividerHeight / 2,
          },
        },
        strokeColor = colors.divider,
        strokeWidth = 1,
      })

      y = y + layout.dividerHeight
    else
      self:appendMenuRow(
        elements,
        menu,
        row,
        rowIndex,
        y,
        navigationPositionByRow[rowIndex],
        checkedRows[rowIndex] == true
      )

      y = y + layout.rowHeight
    end
  end

  self.canvas:appendElements(elements)
  self.canvas:wantsLayer(true)
  self.canvas:show()
end

--- Update the rendered scale of one row for the loupe effect.
---@param menu table
---@param rowIndex integer
---@param scale number
function HUD:renderRowScale(menu, rowIndex, scale)
  if not self.canvas then
    return
  end

  local row = menu.rows[rowIndex]
  local visual = menu.rowVisuals[rowIndex]

  if not row or not visual then
    return
  end

  if math.abs(scale - visual.currentScale) < 0.001 then
    return
  end

  visual.currentScale = scale

  local layout = self.layout
  local keyWidth = layout.keyWidth * scale
  local textHeight = layout.textHeight * scale
  local backgroundWidth = layout.keyWidth * scale
  local backgroundHeight = layout.keyBackgroundHeight * scale
  local fontSize = self.config.font.size * scale
  local resizedFont = self.theme.resizedFont(visual.font, fontSize)

  local keyX =
      layout.horizontalPadding - (keyWidth - layout.keyWidth) / 2

  local textY =
      visual.baseY + (layout.rowHeight - textHeight) / 2

  if visual.keyBackgroundIndex then
    self.canvas:elementAttribute(
      visual.keyBackgroundIndex,
      "frame",
      {
        x = layout.horizontalPadding
            - (backgroundWidth - layout.keyWidth) / 2,
        y = visual.baseY
            + (layout.rowHeight - backgroundHeight) / 2,
        w = backgroundWidth,
        h = backgroundHeight,
      }
    )
  end

  self.canvas:elementAttribute(
    visual.keyTextIndex,
    "frame",
    {
      x = keyX,
      y = textY,
      w = keyWidth,
      h = textHeight,
    }
  )

  self.canvas:elementAttribute(
    visual.keyTextIndex,
    "text",
    self.theme.styledText(
      self:displayKey(row),
      resizedFont,
      visual.keyColor,
      "center"
    )
  )

  if visual.checkTextIndex then
    self.canvas:elementAttribute(
      visual.checkTextIndex,
      "frame",
      {
        x = layout.labelX,
        y = textY,
        w = layout.checkWidth,
        h = textHeight,
      }
    )

    self.canvas:elementAttribute(
      visual.checkTextIndex,
      "text",
      self.theme.styledText(
        visual.isChecked and "✓" or "",
        resizedFont,
        self.theme.colors.accent,
        "center"
      )
    )
  end

  self.canvas:elementAttribute(
    visual.labelTextIndex,
    "frame",
    {
      x = visual.labelX,
      y = textY,
      w = self.config.menu.width
          - visual.labelX
          - layout.horizontalPadding,
      h = textHeight,
    }
  )

  self.canvas:elementAttribute(
    visual.labelTextIndex,
    "text",
    self.theme.styledText(
      row.label,
      resizedFont,
      visual.labelColor,
      "left"
    )
  )
end

--- Determine the target scale for a row based on its distance from selection.
---@param menu table
---@param visual table
---@return number
function HUD:targetScale(menu, visual)
  if not self.config.loupe.enabled then
    return 1
  end

  if not menu.selectedPosition or not visual.navigationPosition then
    return 1
  end

  local distance =
      math.abs(visual.navigationPosition - menu.selectedPosition)

  if distance == 0 then
    return self.config.loupe.selectedScale
  end

  if distance == 1 then
    return self.config.loupe.adjacentScale
  end

  return 1
end

--- Move the selection highlight frame to `y`.
---@param menu table
---@param y number
function HUD:setSelectionFrame(menu, y)
  menu.selectionY = y

  self.canvas:elementAttribute(
    menu.selectionElementIndex,
    "frame",
    {
      x = self.layout.selectionInset,
      y = y,
      w = self.config.menu.width - (self.layout.selectionInset * 2),
      h = self.layout.rowHeight - 2,
    }
  )
end

--- Move and animate the selection highlight to the current selected row.
---@param menu table
function HUD:select(menu)
  if not self.canvas then
    return
  end

  self:stopAnimation()

  local selectedVisual = menu.rowVisuals[menu.selectedIndex]

  if not selectedVisual then
    return
  end

  for rowIndex, visual in pairs(menu.rowVisuals) do
    self:renderRowScale(
      menu,
      rowIndex,
      self:targetScale(menu, visual)
    )
  end

  local targetY = selectedVisual.baseY + 1
  local startY = menu.selectionY

  self.canvas:elementAttribute(
    menu.selectionElementIndex,
    "action",
    "fill"
  )

  if not startY
      or not self.config.loupe.enabled
      or self.config.loupe.duration <= 0 then
    self:setSelectionFrame(menu, targetY)
    return
  end

  local startedAt = hs.timer.absoluteTime()

  local function animationStep()
    if not self.canvas then
      self:stopAnimation()
      return
    end

    local elapsed =
        (hs.timer.absoluteTime() - startedAt) / 1000000000

    local progress =
        math.min(elapsed / self.config.loupe.duration, 1)

    local eased = 1 - ((1 - progress) ^ 3)

    self:setSelectionFrame(
      menu,
      startY + (targetY - startY) * eased
    )

    if progress >= 1 then
      self:stopAnimation()
    end
  end

  self.animationTimer = hs.timer.doEvery(
    1 / self.layout.animationFPS,
    animationStep
  )

  animationStep()
end

--- Redraw `menu` and restore the current selection, if any.
---@param menu table
---@param checkedRows table
function HUD:refresh(menu, checkedRows)
  self:show(menu, checkedRows)

  if menu.selectedIndex then
    self:select(menu)
  end
end

return HUD
