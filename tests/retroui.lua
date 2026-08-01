local root = assert(arg[1], "repository root argument is required")
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local canvases, modals, timers = {}, {}, {}
local mouseButtons = {}
local styled = {}
styled.__concat = function(left, right)
    local result = setmetatable({text = "", segments = {}}, styled)
    for _, value in ipairs({left, right}) do
        if getmetatable(value) == styled then
            result.text = result.text .. value.text
            for _, segment in ipairs(value.segments) do table.insert(result.segments, segment) end
        else result.text = result.text .. tostring(value) end
    end
    return result
end
local function styledText(text, attributes) return setmetatable({text = text, segments = {{text = text, attributes = attributes}}}, styled) end
local function canvas(frame)
    local value = {frameValue = frame, replaceCalls = 0, elementUpdates = 0}
    function value:replaceElements(elements) self.elements = elements; self.replaceCalls = self.replaceCalls + 1; return self end
    function value:elementAttribute(index, key, item) self.elements[index][key] = item; self.elementUpdates = self.elementUpdates + 1; return self end
    function value:wantsLayer(flag) self.layer = flag; return self end
    function value:level(level) self.levelValue = level; return self end
    function value:clickActivating(flag) self.activating = flag; return self end
    function value:mouseCallback(callback) self.mouse = callback; return self end
    function value:canvasMouseEvents(down, up, enterExit, move) self.canvasEvents = {down, up, enterExit, move}; return self end
    function value:show() self.visible = true; return self end
    function value:delete() self.deleted, self.visible = true, false end
    table.insert(canvases, value)
    return value
end
local function elementById(value, id)
    for _, element in ipairs(value.elements) do
        if element.id == id then return element end
    end
end
local function modal()
    local value = {bindings = {}}
    function value:bind(modifiers, key, pressed, released) self.bindings[key .. (#modifiers > 0 and "+shift" or "")] = {pressed = pressed, released = released}; return self end
    function value:enter() self.entered = true; return self end
    function value:delete() self.deleted = true end
    table.insert(modals, value)
    return value
end
hs = {
    styledtext = {new = styledText, convertFont = function(font, bold) local out = {}; for key, value in pairs(font) do out[key] = value end; out.bold = bold; return out end, fontInfo = function() return {fixedPitch = true, maximumAdvancement = {w = 11}, ascender = 14, descender = -4, leading = 2} end},
    canvas = {new = canvas, windowLevels = {desktopIcon = 10, floating = 20}},
    screen = {mainScreen = function() return {frame = function() return {x = 0, y = 0, w = 1280, h = 800} end} end},
    hotkey = {modal = {new = modal}},
    eventtap = {checkMouseButtons = function() return mouseButtons end},
    timer = {doAfter = function(duration, callback) local value = {duration = duration, callback = callback}; function value:stop() self.stopped = true end; function value:fire() if not self.stopped and not self.fired then self.fired = true; self.callback() end end; table.insert(timers, value); return value end}
}

local RetroUI = require("lib.RetroUI")
local rendered = RetroUI.Frame.render({style = "double", title = {text = "Title", alignment = "center"}, padding = {top = 1, bottom = 1, left = 2, right = 3}, rows = {{text = "Hello", role = "body"}}})
assert(rendered.columns > 0 and RetroUI.Frame.toString(rendered):match("Title"), "frame must render title")
local asymmetric = RetroUI.Frame.toString(RetroUI.Frame.render({style = "single", title = {text = "T", alignment = "left"}, padding = {top = 1, bottom = 1, left = 2, right = 3}, rows = {{text = "X", role = "body"}}}))
assert(asymmetric == "┌─[ T ]─┐\n│       │\n│  X    │\n│       │\n└───────┘",
       "all four frame paddings must contribute to every row")
local snapshot = RetroUI.Frame.toString(RetroUI.Frame.render({style = "double", title = {text = "Title", alignment = "left"}, padding = {top = 0, bottom = 0, left = 0, right = 0}, rows = {{text = "Body", role = "body"}}}))
assert(snapshot == "╔═[ Title ]═╗\n║Body       ║\n╚═══════════╝", "frame snapshot changed")
for _, alignment in ipairs({"left", "center", "right"}) do
    assert(RetroUI.Frame.render({style = "single", title = {text = "T", alignment = alignment}, padding = {top = 0, bottom = 0, left = 0, right = 0}, rows = {}}), "every title alignment must render")
end
local boxGlyphTitle = RetroUI.Frame.render({style = "double", title = {text = "╔", alignment = "left"}, padding = {top = 0, bottom = 0, left = 0, right = 0}, rows = {}})
assert(boxGlyphTitle.columns == 9, "known box glyphs must occupy one display cell")
assert(not pcall(function() RetroUI.Frame.render({style = "bad"}) end), "invalid frame must fail")
assert(not pcall(function() RetroUI.Frame.render({style = "single", title = {text = "T", alignment = "left"}, padding = {top = 0, right = 0, bottom = 0, left = 0}, rows = {[2] = {text = "hole", role = "body"}}}) end),
       "frame rows must be a dense array")
local borland = RetroUI.Theme.resolve("borland")
assert(borland.id == "borland" and borland.button.pressed.faceColor and
           borland.button.shadowOffset.x == 6 and
           borland.button.shadowOffset.y == 6 and
           borland.button.pressOffset.x == 6 and
           borland.button.pressOffset.y == 6,
       "borland theme must resolve with its pronounced button depth")
local overrides = {dialog = {backgroundColor = {red = 0.2, green = 0.2, blue = 0.2, alpha = 1}}}
local customized = RetroUI.Theme.resolve("borland", overrides)
assert(customized.dialog.backgroundColor.red == 0.2 and borland.dialog.backgroundColor.red == 0, "theme overrides must not mutate presets")
assert(not pcall(function() RetroUI.Theme.resolve("borland", {dialog = {unknown = true}}) end), "unknown theme fields must fail")
assert(not pcall(function() RetroUI.Theme.resolve("borland", {button = {pressOffset = {x = "bad"}}}) end), "invalid theme geometry must fail during resolution")
assert(not pcall(function() RetroUI.Theme.resolve("borland", {dialog = {backgroundColor = {white = 0, alpha = 1, extra = true}}}) end), "unknown color fields must fail")
assert(not pcall(function() RetroUI.Theme.resolve("borland", {dialog = {backgroundColor = {white = 0 / 0, alpha = 1}}}) end),
       "non-finite theme values must fail")
local group = RetroUI.ButtonGroup.new({{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}, {id = "cancel", label = "Cancel", hotkey = "c", default = false, enabled = true}})
assert(group:focusRelative(1) and group.focusedId == "ok", "first tab must focus first button")
assert(group:arm("ok", "mouse") and group:activate("ok", "mouse").id == "ok", "mouse activation must match arm")
local disabled = RetroUI.ButtonGroup.new({{id = "disabled", label = "Disabled", hotkey = "d", default = false, enabled = false}, {id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}})
assert(disabled:focusRelative(1) and disabled.focusedId == "ok" and not disabled:arm("disabled", "mouse"), "disabled buttons must not receive focus or presses")
assert(not pcall(function() RetroUI.ButtonGroup.new({{id = "one", label = "One", hotkey = "o", default = true, enabled = true}, {id = "two", label = "Two", hotkey = "o", default = false, enabled = true}}) end), "duplicate mnemonics must fail")
assert(not pcall(function() RetroUI.ButtonGroup.new({[2] = {id = "two", label = "Two", hotkey = "t", default = false, enabled = true}}) end),
       "buttons must be a dense array")
assert(not pcall(function() RetroUI.ButtonGroup.new({{id = "bad", label = "Bad", hotkey = "return", default = true, enabled = true}}) end),
       "mnemonics must be one bindable ASCII character")
assert(RetroUI.ButtonGroup.new({{id = "plain", label = "Plain", hotkey = "p", default = false, enabled = true}}):default() == nil,
       "Return must remain unbound when no button is default")
assert(not pcall(function()
    RetroUI.Dialog.show({theme = "monochrome", title = "Bad footer",
                         content = {}, footer = {text = "Dismiss", role = "notice", buttonId = "missing"},
                         buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}})
end), "footer actions must reference an existing button")

local dismissed = {}
local dialog = RetroUI.Dialog.show({theme = "danger", themeOverrides = {typography = {titleWeight = "regular", bodyWeight = "bold", noticeWeight = "regular"}}, title = "Problem", titleAlignment = "left", frameStyle = "single", padding = {top = 1, right = 3, bottom = 1, left = 3}, content = {{text = "Broken", role = "body"}, {text = "Wait", role = "notice"}, {text = "Key", role = "hotkey"}}, buttons = {{id = "dismiss", label = "OK", hotkey = "o", default = true, enabled = true}}, dismissAfter = 30, dismissOnEscape = false, dismissOnBackgroundClick = false, onDismiss = function(reason, id) table.insert(dismissed, {reason, id}) end})
assert(dialog.frame.lines[1].runs[1].text:find("^┌"), "dialog must allow a single-line frame override")
assert(dialog:isVisible() and #canvases == 1 and canvases[1].levelValue == 20 and not canvases[1].activating, "dialog canvas must be interactive at floating level")
local warningLabel = canvases[1].elements[5].text
assert(#warningLabel.segments == 2 and warningLabel.segments[1].attributes.color.red == 0.72 and warningLabel.segments[2].attributes.color.white == 0,
       "button mnemonic and ordinary label text must use distinct theme colors")
local semantic = {}
for _, segment in ipairs(canvases[1].elements[2].text.segments) do
    semantic[segment.text] = segment.attributes
end
assert(semantic.Problem.font.bold == nil and semantic.Broken.font.bold and
           semantic.Wait.font.bold == nil and semantic.Key.color.red == 1,
       "semantic colors and every configured typography weight must reach styled text")
modals[1].bindings["return"].pressed()
assert(dialog.group.armedId == "dismiss", "return down must press default")
assert(canvases[1].replaceCalls == 1 and canvases[1].elementUpdates > 0,
       "button state changes must update elements without rebuilding the canvas")
local pressedY = canvases[1].elements[4].frame.y
modals[1].bindings["return"].released()
assert(canvases[1].elements[4].frame.y == pressedY and dialog.activationPending,
       "the pressed face must remain visible through the release delay")
local releaseTimerCount = #timers
modals[1].bindings["return"].released()
assert(#timers == releaseTimerCount,
       "repeated release callbacks must not schedule duplicate activation")
timers[#timers]:fire()
assert(dismissed[1][1] == "button" and dismissed[1][2] == "dismiss" and not dialog:isVisible(), "return up must dismiss")

local mouseDismissed = {}
local clicked = RetroUI.Dialog.show({theme = "borland", themeOverrides = {}, title = "Click", titleAlignment = "center", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}, dismissAfter = 30, dismissOnEscape = false, dismissOnBackgroundClick = false, onDismiss = function(reason) table.insert(mouseDismissed, reason) end})
local activeCanvas = canvases[#canvases]
mouseButtons = {left = true}
activeCanvas.mouse(activeCanvas, "mouseDown", "retro-ui:button:ok:hit")
assert(clicked.group.armedId == "ok", "left down must arm")
mouseButtons = {}
activeCanvas.mouse(activeCanvas, "mouseUp", "retro-ui:button:ok:hit")
assert(activeCanvas.elements[4].frame.y == activeCanvas.elements[3].frame.y and
           clicked.activationPending,
       "mouse release must retain the pressed visual through the release delay")
timers[#timers]:fire()
assert(mouseDismissed[1] == "button", "left click must dismiss")

local ignored = RetroUI.Dialog.show({theme = "monochrome", themeOverrides = {}, title = "Right", titleAlignment = "right", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}, dismissAfter = 30, dismissOnEscape = false, dismissOnBackgroundClick = false, onDismiss = function() end})
activeCanvas = canvases[#canvases]
mouseButtons = {right = true}
activeCanvas.mouse(activeCanvas, "mouseDown", "retro-ui:button:ok:hit")
assert(ignored.group.armedId == nil, "right click must not arm")
ignored.timeoutTimer:fire()
assert(ignored.closed, "timeout must dismiss")

local transitions = {}
local twoButtons = RetroUI.Dialog.show({theme = "monochrome", themeOverrides = {}, title = "Buttons", titleAlignment = "right", content = {{text = "Test", role = "body"}}, buttons = {{id = "one", label = "One", hotkey = "o", default = true, enabled = true}, {id = "two", label = "Two", hotkey = "t", default = false, enabled = true}}, dismissOnEscape = false, dismissOnBackgroundClick = false, onDismiss = function(reason, id) table.insert(transitions, {reason, id}) end})
local twoCanvas, twoModal = canvases[#canvases], modals[#modals]
local lastHit = twoCanvas.elements[#twoCanvas.elements]
assert(lastHit.frame.x + lastHit.frame.w <= twoCanvas.frameValue.w,
       "the canvas must contain the complete multi-button row")
twoModal.bindings["tab"].pressed()
assert(twoButtons.group.focusedId == "one", "Tab must move focus forward")
twoModal.bindings["tab+shift"].pressed()
assert(twoButtons.group.focusedId == "two", "Shift-Tab must wrap focus backward")
mouseButtons = {left = true}
twoCanvas.mouse(twoCanvas, "mouseDown", "retro-ui:button:one:hit")
twoCanvas.mouse(twoCanvas, "mouseExit", "retro-ui:button:one:hit")
twoCanvas.mouse(twoCanvas, "mouseUp", "retro-ui:button:one:hit")
assert(not twoButtons.closed and twoButtons.group.armedId == nil, "mouse exit must cancel a press")
twoCanvas.mouse(twoCanvas, "mouseDown", "retro-ui:button:one:hit")
mouseButtons = {}
twoCanvas.mouse(twoCanvas, "mouseUp", "retro-ui:button:two:hit")
assert(not twoButtons.closed and twoButtons.group.armedId == nil, "mouse-up on another button must not activate")
twoModal.bindings["o"].pressed()
twoModal.bindings["o"].released()
timers[#timers]:fire()
assert(transitions[1][1] == "button" and transitions[1][2] == "one", "mnemonic down/up must share button activation")

local geometry = RetroUI.Dialog.show({theme = "monochrome", themeOverrides = {dialog = {outerPadding = {top = 3, right = 29, bottom = 7, left = 5}}, button = {padding = {top = 2, right = 37, bottom = 13, left = 3}, shadowOffset = {x = 2, y = 3}, pressOffset = {x = 9, y = 11}}}, title = "Geometry", content = {{text = "Test", role = "body"}}, buttons = {{id = "long", label = "Long button", hotkey = "l", default = true, enabled = true}}})
local geometryCanvas = canvases[#canvases]
local geometryLayout = geometry.renderer.buttonLayouts.long
assert(geometryCanvas.elements[2].frame.x == 5 and
           geometryCanvas.elements[2].frame.w == geometryCanvas.frameValue.w -
               5 - 29 and geometryLayout.w == 11 * #"Long button" + 3 + 37 and
           geometryLayout.h == geometry.renderer.lineHeight + 2 + 13,
       "asymmetric dialog and button padding must control geometry")
local geometryHit = geometryCanvas.elements[6]
assert(geometryHit.frame.w == geometryLayout.w + 9 and
           geometryHit.frame.h == geometryLayout.h + 11,
       "hit geometry must contain the larger shadow or press offset")
modals[#modals].bindings["return"].pressed()
assert(geometryCanvas.elements[4].frame.x == geometryLayout.x + 9 and
           geometryCanvas.elements[4].frame.y == geometryLayout.y + 11,
       "configured press offsets must move the face and label")
geometry:delete()

local footerDismissed
local footerDialog = RetroUI.Dialog.show({theme = "borland", title = "Footer", content = {{text = "A deliberately wide content row keeps the footer action apart.", role = "body"}}, footer = {text = "Dismissed in 30 seconds.", role = "notice", buttonId = "accept"}, buttons = {{id = "accept", label = "Accept", hotkey = "a", default = true, enabled = true}, {id = "cancel", label = "Cancel", hotkey = "c", default = false, enabled = true}}, onDismiss = function(reason, id) footerDismissed = {reason, id} end})
local footerCanvas = canvases[#canvases]
local footerText = assert(elementById(footerCanvas, "retro-ui:footer:text"))
local footerFace = assert(elementById(footerCanvas, "retro-ui:button:accept:face"))
local footerShadow = assert(elementById(footerCanvas,
                                        "retro-ui:button:accept:shadow"))
local standardFace = assert(elementById(footerCanvas, "retro-ui:button:cancel:face"))
assert(footerFace.frame.x >= footerText.frame.x + footerText.frame.w +
           footerDialog.theme.button.gap and
           footerShadow.frame.x + footerShadow.frame.w ==
               footerCanvas.frameValue.w -
                   footerDialog.theme.dialog.outerPadding.right and
           footerFace.frame.y <= footerText.frame.y and
           standardFace.frame.y > footerFace.frame.y,
       "footer action must share the row and end at the right content edge")
mouseButtons = {left = true}
footerCanvas.mouse(footerCanvas, "mouseDown", "retro-ui:button:accept:hit")
mouseButtons = {}
footerCanvas.mouse(footerCanvas, "mouseUp", "retro-ui:button:accept:hit")
timers[#timers]:fire()
assert(footerDismissed[1] == "button" and footerDismissed[2] == "accept",
       "footer actions must use the ordinary button state machine")

local heldRelease = RetroUI.Dialog.show({theme = "danger", title = "Held", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}, onDismiss = function() end})
local heldCanvas = canvases[#canvases]
mouseButtons = {left = true}
heldCanvas.mouse(heldCanvas, "mouseDown", "retro-ui:button:ok:hit")
heldCanvas.mouse(heldCanvas, "mouseUp", "retro-ui:button:ok:hit")
assert(heldRelease.group.armedId == "ok" and not heldRelease.closed,
       "another mouse-button release must not complete a held left click")
mouseButtons = {}
heldCanvas.mouse(heldCanvas, "mouseUp", "retro-ui:button:ok:hit")
timers[#timers]:fire()
assert(heldRelease.closed, "the matching left release must activate")

local backgroundReason
local background = RetroUI.Dialog.show({theme = "monochrome", title = "Background", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}, dismissOnBackgroundClick = true, onDismiss = function(reason) backgroundReason = reason end})
local backgroundCanvas = canvases[#canvases]
assert(backgroundCanvas.canvasEvents[1] and backgroundCanvas.canvasEvents[2],
       "background dismissal must enable canvas-wide down/up events")
mouseButtons = {left = true}
backgroundCanvas.mouse(backgroundCanvas, "mouseDown", "canvas")
mouseButtons = {}
backgroundCanvas.mouse(backgroundCanvas, "mouseUp", "canvas")
assert(background.closed and backgroundReason == "programmatic",
       "a matching background click must dismiss programmatically")

local reasonGuard = RetroUI.Dialog.show({theme = "monochrome", title = "Reason", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}})
assert(not pcall(function() reasonGuard:dismiss("invalid") end) and
           not reasonGuard.closed,
       "unsupported dismissal reasons must fail before cleanup")
reasonGuard:delete()
assert(reasonGuard:delete() == false,
       "repeated dialog deletion must be harmless")

local raceCalls = 0
local race = RetroUI.Dialog.show({theme = "monochrome", title = "Race", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}, dismissAfter = 30, onDismiss = function(reason) raceCalls = raceCalls + 1; assert(reason == "timeout") end})
local raceTimeout = race.timeoutTimer
modals[#modals].bindings["return"].pressed()
modals[#modals].bindings["return"].released()
local raceRelease = race.releaseTimer
raceTimeout:fire()
raceRelease:fire()
assert(race.closed and raceCalls == 1 and raceRelease.stopped,
       "timeout and activation races must dismiss and clean exactly once")

local callbackCanvasIndex, callbackModalIndex = #canvases + 1, #modals + 1
local callbackDialog = RetroUI.Dialog.show({theme = "monochrome", title = "Callback", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}, dismissAfter = 30, onDismiss = function() error("callback failure") end})
local callbackAccepted, callbackError = pcall(function() callbackDialog:delete() end)
assert(not callbackAccepted and tostring(callbackError):match("callback failure") and
           callbackDialog.closed and canvases[callbackCanvasIndex].deleted and
           modals[callbackModalIndex].deleted and
           callbackDialog.timeoutTimer == nil,
       "callback failure must be reported only after every native resource is cleaned")

local originalModalNew = hs.hotkey.modal.new
local rollbackCallback = false
hs.hotkey.modal.new = function()
    local value = modal()
    local originalBind, calls = value.bind, 0
    function value:bind(...)
        calls = calls + 1
        if calls == 2 then error("bind failure") end
        return originalBind(self, ...)
    end
    return value
end
local rollbackCanvasIndex, rollbackModalIndex = #canvases + 1, #modals + 1
local rollbackAccepted, rollbackError = pcall(function()
    RetroUI.Dialog.show({theme = "monochrome", title = "Rollback", content = {{text = "Test", role = "body"}}, buttons = {{id = "ok", label = "OK", hotkey = "o", default = true, enabled = true}}, onDismiss = function() rollbackCallback = true end})
end)
hs.hotkey.modal.new = originalModalNew
assert(not rollbackAccepted and tostring(rollbackError):match("bind failure") and
           canvases[rollbackCanvasIndex].deleted and
           modals[rollbackModalIndex].deleted and not rollbackCallback,
       "partial key binding failure must roll back without reporting a dismissal")

print("RetroUI tests passed")
