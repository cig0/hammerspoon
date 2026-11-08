--- Canvas-based HUD renderer.
--
-- Builds the visual menu with an optional accent border, header, passive legend,
-- rows, dividers, selection highlight, and optional loupe scaling animation.
-- Receives assembled menus from loader.lua and colors/fonts from theme.lua.
-- Runtime owns key handling and selection; this module owns the canvas.
-- To change section order or labels, edit menus/*.lua. Change spacing here.
-- Geometry uses macOS points. Element frames are relative to the canvas;
-- the canvas frame itself is positioned in screen coordinates.
local HUD = {}

---@class HUD
---@field config table
---@field theme table
---@field canvas any
---@field animationTimer any
---@field layout table
HUD.__index = HUD

local verticalPositions = { top = 0.25, center = 0.50, bottom = 0.75 }

local windowShadows = {
  { blurRadius = 44, offset = { w = 0, h = -8 }, color = { white = 0, alpha = 0.24 } },
  { blurRadius = 22, offset = { w = 0, h = -8 }, color = { white = 0, alpha = 0.34 } },
  { blurRadius = 3,  offset = { w = 0, h = -1 }, color = { white = 0, alpha = 0.30 } }
}

local keyDisplayNames = { escape = "esc", ["return"] = "↩" }

--- Round to the nearest integer.
---@param value number
---@return integer
local function round(value) return math.floor(value + 0.5) end

--- Return a font table sized for the loupe animation.
---@param font table
---@param size number
---@return table
local function resizedFont(font, size)
  local result = { size = size }

  if font.name then result.name = font.name end

  return result
end

--- Build styled text for a canvas element.
---@param text string
---@param font table
---@param color table
---@param alignment? string
---@return any
local function styledText(text, font, color, alignment)
  return hs.styledtext.new(text, {
    font = font,
    color = color,
    paragraphStyle = {
      alignment = alignment or "left",
      lineBreak = "truncateTail"
    }
  })
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

  self:refreshLayout()
  return self
end

--- Recompute geometry after a local font-size preview.
function HUD:refreshLayout()
  local config = self.config
  local scale = config.font.size / 14

  -- Geometry starts at the 14 pt baseline, then scales with the text.
  -- menuContentTop() reserves the same header space that show() draws.
  self.layout = {
    horizontalPadding = 28,
    keyGap = 14,
    checkWidth = 22,
    selectionInset = 18,
    animationFPS = 60,
    headerTop = 25,
    headerHeight = math.max(32, round(config.font.titleSize / scale + 12)),
    rowHeight = 30,
    textHeight = 22,
    keyWidth = 36,
    keyBackgroundHeight = 23,
    dividerHeight = 17,
    legendFontSize = 12,
    legendTextHeight = 18,
    legendBottomSpacing = 8,
    accentBorderWidth = 2,
    capsLockWarningWidth = 105,
    bottomPadding = 16
  }

  for key, value in pairs(self.layout) do
    if key ~= "animationFPS" and key ~= "accentBorderWidth" then
      self.layout[key] = round(value * scale)
    end
  end

  -- show() may compress the root on short screens. Preserve these values
  -- so opening a submenu restores its usual spacing.
  self.normalRowHeight = self.layout.rowHeight
  self.normalDividerHeight = self.layout.dividerHeight
  self.layout.contentTop = self.layout.headerTop + self.layout.headerHeight

  self.layout.labelX = self.layout.horizontalPadding + self.layout.keyWidth +
      self.layout.keyGap
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

--- Return the first menu-row position after optional passive header content.
---@param menu table
---@return number
function HUD:menuContentTop(menu)
  -- The Hyper reference and optional legend sit above navigable rows.
  -- Height calculation, row drawing, and the selection frame share this offset.
  local top = self.layout.contentTop
  if menu.quickLaunchKeys and #menu.quickLaunchKeys > 0 then
    local lines = 1 + math.ceil(#menu.quickLaunchKeys / 3)
    top = top + lines * self.layout.legendTextHeight + self.layout.dividerHeight
  end
  if menu.legend then
    local _, newlines = menu.legend:gsub("\n", "")
    top = top + (newlines + 1) * self.layout.legendTextHeight +
        self.layout.legendBottomSpacing
  end
  return top
end

--- Calculate the total canvas height for `menu`.
---@param menu table
---@return number
function HUD:calculateHeight(menu)
  local height = self:menuContentTop(menu) + self.layout.bottomPadding

  for _, row in ipairs(menu.rows) do
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
  if row.key == nil then return "" end
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
function HUD:appendMenuRow(elements, menu, row, rowIndex, y, navigationPosition,
                           isChecked)
  local layout = self.layout
  local colors = self.theme.colors
  local isGroup = row.kind == "group"
  local isFooter = row.kind == "footer"

  local shouldHighlightGroupKey = self.config.menu.highlightGroups and isGroup

  local font = isGroup and self.theme.fonts.group or self.theme.fonts.body

  local labelColor = isFooter and colors.secondary or colors.primary

  local keyColor = colors.secondary

  if isGroup then
    keyColor = shouldHighlightGroupKey and colors.accentText or colors.accent
  end

  local keyBackgroundY = y + (layout.rowHeight - layout.keyBackgroundHeight) /
      2

  local textY = y + (layout.rowHeight - layout.textHeight) / 2

  local keyBackgroundIndex

  if shouldHighlightGroupKey then
    keyBackgroundIndex = appendElement(elements, {
      type = "rectangle",
      action = "fill",
      frame = {
        x = layout.horizontalPadding,
        y = keyBackgroundY,
        w = layout.keyWidth,
        h = layout.keyBackgroundHeight
      },
      fillColor = colors.accent,
      roundedRectRadii = { xRadius = 5, yRadius = 5 }
    })
  end

  local keyTextIndex = appendElement(elements, {
    type = "text",
    frame = {
      x = layout.horizontalPadding,
      y = textY,
      w = layout.keyWidth,
      h = layout.textHeight
    },
    text = styledText(self:displayKey(row), font, keyColor, "center")
  })

  local checkTextIndex
  local labelX = layout.labelX

  -- Reserve this column for every row when any row is checkable.
  -- Otherwise labels would shift sideways when a check changes.
  if menu.hasChecks then
    checkTextIndex = appendElement(elements, {
      type = "text",
      frame = {
        x = layout.labelX,
        y = textY,
        w = layout.checkWidth,
        h = layout.textHeight
      },
      text = styledText(isChecked and "✓" or "", font, colors.accent,
        "center")
    })

    labelX = labelX + layout.checkWidth
  end

  local labelTextIndex = appendElement(elements, {
    type = "text",
    frame = {
      x = labelX,
      y = textY,
      w = self.config.menu.width - labelX - layout.horizontalPadding,
      h = layout.textHeight
    },
    text = styledText(row.label, font, labelColor, "left")
  })

  -- Cache canvas element indices and unscaled geometry. Selection updates
  -- these elements in place instead of rebuilding the menu on every arrow press.
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
    labelTextIndex = labelTextIndex
  }
end

function HUD:appendDivider(elements, y)
  appendElement(elements, {
    type = "segments",
    action = "stroke",
    coordinates = {
      {
        x = self.layout.horizontalPadding,
        y = y + self.layout.dividerHeight / 2
      }, {
      x = self.config.menu.width - self.layout.horizontalPadding,
      y = y + self.layout.dividerHeight / 2
    }
    },
    strokeColor = self.theme.colors.divider,
    strokeWidth = 1
  })
end

--- Display-only shortcuts, alphabetized down each column.
-- Loader supplies sorted keys and resolved app/menu labels. These lines have
-- no navigation positions, so arrow selection starts at the first menu row.
---@param elements table
---@param keys table Sorted shortcut letters.
---@param labels table Display label indexed by shortcut letter.
function HUD:appendQuickLaunch(elements, keys, labels)
  local layout = self.layout
  local font = resizedFont(self.theme.fonts.body, layout.legendFontSize)
  local y = layout.contentTop
  local function label(id, text, x, top, width, color)
    appendElement(elements, {
      id = id,
      type = "text",
      frame = { x = x, y = top, w = width, h = layout.legendTextHeight },
      text = styledText(text, font, color)
    })
  end

  local width = self.config.menu.width - 2 * layout.horizontalPadding
  label("hyper-heading", "Hyperkey (Caps Lock)", layout.horizontalPadding, y,
    width, self.theme.colors.secondary)
  y = y + layout.legendTextHeight
  -- Fill top-to-bottom, left-to-right. Matches loader key order.
  local rows = math.ceil(#keys / 3)
  for index, key in ipairs(keys) do
    local column = math.floor((index - 1) / rows)
    local row = (index - 1) % rows
    label("hyper-" .. key, key .. "   " .. labels[key],
      layout.horizontalPadding + column * width / 3,
      y + row * layout.legendTextHeight, width / 3, self.theme.colors.primary)
  end
  self:appendDivider(elements, y + rows * layout.legendTextHeight)
end

--- Build and display the canvas for `menu`.
---@param menu table
---@param checkedRows table
function HUD:show(menu, checkedRows)
  self:close()
  self.theme:refreshFontSizes()
  self:refreshLayout()

  menu.rowVisuals = {}
  menu.selectionY = nil

  -- rowIndex includes dividers; navigation positions count selectable rows.
  -- Keep that distinction when changing row layout or loupe behavior.
  local navigationPositionByRow = {}

  for position, rowIndex in ipairs(menu.navigableRows) do
    navigationPositionByRow[rowIndex] = position
  end

  local screen = self:targetScreen()

  assert(screen, "Gearbox: no screen is available for the HUD")

  -- frame() excludes the menu bar and Dock. Position within the unused height,
  -- so top/bottom share the same margin even on screens with different origins.
  local screenFrame = screen:frame()
  local layout = self.layout
  layout.rowHeight = self.normalRowHeight
  layout.dividerHeight = self.normalDividerHeight
  local height = self:calculateHeight(menu)
  if height > screenFrame.h and menu.quickLaunchKeys and #menu.quickLaunchKeys > 0 then
    -- Reclaim row padding on short screens so the root footer stays visible.
    layout.rowHeight = math.max(layout.textHeight, layout.keyBackgroundHeight)
    layout.dividerHeight = math.ceil(self.normalDividerHeight / 2)
    height = self:calculateHeight(menu)
  end
  local contentHeight = height
  height = math.min(height, screenFrame.h)
  menu.scrollOffset = 0
  menu.viewportTop = self:menuContentTop(menu)
  menu.viewportHeight = height - layout.bottomPadding - menu.viewportTop
  menu.overflow = contentHeight > height
  local availableHeight = math.max(0, screenFrame.h - height)

  local posX = screenFrame.x + (screenFrame.w - self.config.menu.width) / 2

  local posY = screenFrame.y + availableHeight *
      verticalPositions[self.config.menu.position]

  -- Anchor the painted panel first. Only its transparent shadow margin may
  -- shrink at a screen edge. Row and animation coordinates stay panel-local.
  local margin = self.config.menu.showWindowShadow and 88 or 0
  local side = math.min(margin, math.max(0, posX - screenFrame.x))
  local top = math.min(margin, posY - screenFrame.y)
  local bottom = math.min(margin, math.max(0, screenFrame.y + screenFrame.h - posY - height))
  self.canvas = hs.canvas.new({
    x = posX - side,
    y = posY - top,
    w = self.config.menu.width + 2 * side,
    h = height + top + bottom
  })
  self.canvas:transformation(hs.canvas.matrix.translate(side, top))

  local colors = self.theme.colors
  local elements = {}
  local rootMenuCapsLockIsOn = false

  if menu.parentId == nil then
    -- `hs.hid.capslock.get()` reads the hardware state directly. Sampling
    -- here keeps Gearbox free of Caps Lock watchers and synchronized state.
    rootMenuCapsLockIsOn = hs.hid.capslock.get()
  end

  local panel = { x = 0, y = 0, w = self.config.menu.width, h = height }
  local radius = self.theme.metrics.windowCornerRadius
  local corners = { xRadius = radius, yRadius = radius }
  if self.config.menu.showWindowShadow then
    -- A soft lower shadow gives the panel depth. A tighter shadow defines
    -- the edge. NSShadow uses negative vertical offsets to cast downward.
    for _, shadow in ipairs(windowShadows) do
      appendElement(elements, {
        type = "rectangle",
        action = "fill",
        frame = panel,
        roundedRectRadii = corners,
        fillColor = { white = 0, alpha = 1 },
        withShadow = true,
        shadow = shadow
      })
    end
  end

  -- Replace the opaque shadow casters inside the panel. At 50% opacity
  -- the desktop shows through without an extra layer of black underneath.
  local background = {}
  for key, value in pairs(colors.background) do background[key] = value end
  background.alpha = self.config.menu.backgroundOpacity / 100
  appendElement(elements, {
    id = "menu-background",
    type = "rectangle",
    action = "fill",
    frame = panel,
    roundedRectRadii = corners,
    fillColor = background,
    compositeRule = "copy"
  })

  if self.config.menu.showAccentBorder then
    local borderInset = layout.accentBorderWidth / 2

    -- `hs.canvas` stroke widths are measured in points. Insetting the path
    -- by half its width keeps the complete outline inside the HUD canvas.
    appendElement(elements, {
      id = "menu-accent-border",
      type = "rectangle",
      action = "stroke",
      frame = {
        x = borderInset,
        y = borderInset,
        w = self.config.menu.width - (borderInset * 2),
        h = height - (borderInset * 2)
      },
      strokeColor = colors.frame,
      strokeWidth = layout.accentBorderWidth,
      roundedRectRadii = {
        xRadius = math.max(0, self.theme.metrics.windowCornerRadius -
          borderInset),
        yRadius = math.max(0, self.theme.metrics.windowCornerRadius -
          borderInset)
      }
    })
  end

  local titleWidth = self.config.menu.width - (layout.horizontalPadding * 2)

  if rootMenuCapsLockIsOn then
    titleWidth = titleWidth - layout.capsLockWarningWidth - layout.keyGap
  end

  appendElement(elements, {
    type = "text",
    frame = {
      x = layout.horizontalPadding,
      y = layout.headerTop,
      w = titleWidth,
      h = layout.headerHeight
    },
    text = styledText(self:displayTitle(menu), self.theme.fonts.title,
      colors.primary, "left")
  })

  if rootMenuCapsLockIsOn then
    local warningX = self.config.menu.width - layout.horizontalPadding -
        layout.capsLockWarningWidth
    local warningY = layout.headerTop +
        (layout.headerHeight -
          layout.keyBackgroundHeight) / 2

    appendElement(elements, {
      id = "caps-lock-warning-background",
      type = "rectangle",
      action = "fill",
      frame = {
        x = warningX,
        y = warningY,
        w = layout.capsLockWarningWidth,
        h = layout.keyBackgroundHeight
      },
      fillColor = colors.primary,
      roundedRectRadii = { xRadius = 5, yRadius = 5 }
    })

    appendElement(elements, {
      id = "caps-lock-warning",
      type = "text",
      frame = {
        x = warningX,
        y = warningY,
        w = layout.capsLockWarningWidth,
        h = layout.keyBackgroundHeight
      },
      text = styledText("CAPS LOCK", self.theme.fonts.group,
        colors.background, "center")
    })
  end

  if menu.quickLaunchKeys and #menu.quickLaunchKeys > 0 then
    self:appendQuickLaunch(elements, menu.quickLaunchKeys, menu.quickLaunchLabels)
  end

  if menu.legend then
    local _, newlines = menu.legend:gsub("\n", "")
    local legendHeight = (newlines + 1) * layout.legendTextHeight

    appendElement(elements, {
      id = "menu-legend",
      type = "text",
      frame = {
        x = layout.horizontalPadding,
        y = self:menuContentTop(menu) - legendHeight - layout.legendBottomSpacing,
        w = self.config.menu.width - (layout.horizontalPadding * 2),
        h = legendHeight
      },
      text = styledText(menu.legend,
        resizedFont(self.theme.fonts.body,
          layout.legendFontSize),
        colors.secondary, "left")
    })
  end

  -- Clip rows to the panel while the title and Hyper reference stay fixed.
  appendElement(elements, {
    type = "rectangle",
    action = "clip",
    frame = { x = 0, y = menu.viewportTop, w = self.config.menu.width, h = menu.viewportHeight }
  })
  menu.firstRowElement = #elements + 1
  menu.selectionElementIndex = appendElement(elements, {
    type = "rectangle",
    action = "skip",
    frame = {
      x = layout.selectionInset,
      y = self:menuContentTop(menu),
      w = self.config.menu.width - (layout.selectionInset * 2),
      h = layout.rowHeight - 2
    },
    fillColor = colors.selection,
    roundedRectRadii = { xRadius = 8, yRadius = 8 }
  })

  local y = self:menuContentTop(menu)

  for rowIndex, row in ipairs(menu.rows) do
    if row.divider then
      self:appendDivider(elements, y)

      y = y + layout.dividerHeight
    else
      self:appendMenuRow(elements, menu, row, rowIndex, y,
        navigationPositionByRow[rowIndex],
        checkedRows[rowIndex] == true)

      y = y + layout.rowHeight
    end
  end

  menu.lastRowElement = #elements
  appendElement(elements, { type = "resetClip" })
  if menu.overflow then
    appendElement(elements, {
      id = "menu-scroll-hint",
      type = "text",
      frame = { x = 0, y = height - layout.bottomPadding, w = self.config.menu.width, h = layout.bottomPadding },
      text = styledText("↑ ↓", resizedFont(self.theme.fonts.body, layout.legendFontSize), colors.secondary, "center")
    })
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
  if not self.canvas then return end

  local row = menu.rows[rowIndex]
  local visual = menu.rowVisuals[rowIndex]

  if not row or not visual then return end

  local selected = rowIndex == menu.selectedIndex
  if math.abs(scale - visual.currentScale) < 0.001 and
      visual.isSelected == selected then
    return
  end
  visual.isSelected = selected
  -- Selection colors must update even with loupe disabled or equal scales.
  -- Cached base colors restore the previous row when the cursor moves.
  local selectedText = selected and self.theme.colors.selectionText
  if visual.keyBackgroundIndex then
    self.canvas:elementAttribute(visual.keyBackgroundIndex, "action",
      selectedText and "skip" or "fill")
  end

  visual.currentScale = scale

  local layout = self.layout
  local keyWidth = layout.keyWidth * scale
  local textHeight = layout.textHeight * scale
  local backgroundWidth = layout.keyWidth * scale
  local backgroundHeight = layout.keyBackgroundHeight * scale
  local fontSize = self.config.font.size * scale
  local scaledFont = resizedFont(visual.font, fontSize)

  -- Scale around each row's original center. baseY and rowHeight stay fixed,
  -- so magnification does not push neighboring rows or change navigation order.
  local keyX = layout.horizontalPadding - (keyWidth - layout.keyWidth) / 2

  local textY = visual.baseY + (layout.rowHeight - textHeight) / 2

  if visual.keyBackgroundIndex then
    self.canvas:elementAttribute(visual.keyBackgroundIndex, "frame", {
      x = layout.horizontalPadding - (backgroundWidth - layout.keyWidth) /
          2,
      y = visual.baseY + (layout.rowHeight - backgroundHeight) / 2,
      w = backgroundWidth,
      h = backgroundHeight
    })
  end

  self.canvas:elementAttribute(visual.keyTextIndex, "frame", {
    x = keyX,
    y = textY,
    w = keyWidth,
    h = textHeight
  })

  self.canvas:elementAttribute(
    visual.keyTextIndex, "text",
    styledText(self:displayKey(row), scaledFont, selectedText or visual.keyColor, "center"))

  if visual.checkTextIndex then
    self.canvas:elementAttribute(visual.checkTextIndex, "frame", {
      x = layout.labelX,
      y = textY,
      w = layout.checkWidth,
      h = textHeight
    })

    self.canvas:elementAttribute(
      visual.checkTextIndex, "text",
      styledText(visual.isChecked and "✓" or "", scaledFont,
        selectedText or self.theme.colors.accent, "center"))
  end

  self.canvas:elementAttribute(visual.labelTextIndex, "frame", {
    x = visual.labelX,
    y = textY,
    w = self.config.menu.width - visual.labelX - layout.horizontalPadding,
    h = textHeight
  })

  self.canvas:elementAttribute(
    visual.labelTextIndex, "text",
    styledText(row.label, scaledFont, selectedText or visual.labelColor, "left"))
end

--- Determine the target scale for a row based on its distance from selection.
---@param menu table
---@param visual table
---@return number
function HUD:targetScale(menu, visual)
  if not self.config.loupe.enabled then return 1 end

  if not menu.selectedPosition or not visual.navigationPosition then
    return 1
  end

  -- Distance follows selectable rows, ignoring divider gaps.
  local distance = math.abs(visual.navigationPosition - menu.selectedPosition)

  if distance == 0 then return self.config.loupe.selectedScale end

  if distance == 1 then return self.config.loupe.adjacentScale end

  return 1
end

--- Move the selection highlight frame to `y`.
---@param menu table
---@param y number
function HUD:setSelectionFrame(menu, y)
  menu.selectionY = y

  self.canvas:elementAttribute(menu.selectionElementIndex, "frame", {
    x = self.layout.selectionInset,
    y = y,
    w = self.config.menu.width - (self.layout.selectionInset * 2),
    h = self.layout.rowHeight - 2
  })
end

--- Move and animate the selection highlight to the current selected row.
---@param menu table
function HUD:select(menu)
  if not self.canvas then return end

  self:stopAnimation()

  local selectedVisual = menu.rowVisuals[menu.selectedIndex]

  if not selectedVisual then return end

  for rowIndex, visual in pairs(menu.rowVisuals) do
    self:renderRowScale(menu, rowIndex, self:targetScale(menu, visual))
  end

  -- Keep the selected row visible. All row elements share the same scroll
  -- translation, including dividers, checks, keycaps, and the highlight.
  local offset = menu.scrollOffset
  local rowTop = selectedVisual.baseY - menu.viewportTop
  offset = math.max(offset, rowTop + self.layout.rowHeight - menu.viewportHeight)
  offset = math.max(0, math.min(offset, rowTop))
  if offset ~= menu.scrollOffset then
    menu.scrollOffset = offset
    menu.selectionY = nil
    local translation = hs.canvas.matrix.translate(0, -offset)
    for index = menu.firstRowElement, menu.lastRowElement do
      self.canvas:elementAttribute(index, "transformation", translation)
    end
  end

  local targetY = selectedVisual.baseY + 1
  local startY = menu.selectionY

  self.canvas:elementAttribute(menu.selectionElementIndex, "action", "fill")

  if not startY or not self.config.loupe.enabled or self.config.loupe.duration <=
      0 then
    self:setSelectionFrame(menu, targetY)
    return
  end

  local startedAt = hs.timer.absoluteTime()

  local function animationStep()
    if not self.canvas then
      self:stopAnimation()
      return
    end

    -- absoluteTime() returns nanoseconds; loupe.duration is in seconds.
    local elapsed = (hs.timer.absoluteTime() - startedAt) / 1000000000

    local progress = math.min(elapsed / self.config.loupe.duration, 1)

    -- Cubic ease-out slows the highlight as it reaches the selected row.
    local eased = 1 - ((1 - progress) ^ 3)

    self:setSelectionFrame(menu, startY + (targetY - startY) * eased)

    if progress >= 1 then self:stopAnimation() end
  end

  self.animationTimer = hs.timer.doEvery(1 / self.layout.animationFPS,
    animationStep)

  animationStep()
end

--- Redraw `menu` and restore the current selection, if any.
---@param menu table
---@param checkedRows table
function HUD:refresh(menu, checkedRows)
  self:show(menu, checkedRows)

  if menu.selectedIndex then self:select(menu) end
end

return HUD
