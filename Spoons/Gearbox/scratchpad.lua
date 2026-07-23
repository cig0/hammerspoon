local Scratchpad = {}
Scratchpad.__index = Scratchpad

local settingsKey = "Gearbox.scratchpad.content"

local verticalPositions = {
  top = 0.25,
  center = 0.50,
  bottom = 0.75,
}

local document = [[
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1, maximum-scale=1"
  >
  <style>
    :root {
      --background: rgba(32, 32, 32, 1);
      --primary: rgba(255, 255, 255, 1);
      --secondary: rgba(255, 255, 255, 0.6);
      --divider: rgba(255, 255, 255, 0.15);
      --accent: rgba(10, 122, 255, 1);
      --selection: rgba(10, 122, 255, 0.25);
      --corner-radius: 16px;
      --body-size: 14px;
      --title-size: 20px;
      --footer-size: 12px;
      --body-weight: 400;
      --title-weight: 700;
    }

    * {
      box-sizing: border-box;
    }

    html,
    body {
      width: 100%;
      height: 100%;
      margin: 0;
      overflow: hidden;
      background: transparent;
    }

    #panel {
      display: flex;
      width: 100%;
      height: 100%;
      flex-direction: column;
      overflow: hidden;
      color: var(--primary);
      background: var(--background);
      border-radius: var(--corner-radius);
    }

    #title {
      flex: 0 0 auto;
      padding: 22px 26px 12px;
      color: var(--primary);
      font-size: var(--title-size);
      font-weight: var(--title-weight);
      line-height: 1.2;
      user-select: none;
    }

    #editor {
      width: 100%;
      min-height: 0;
      flex: 1 1 auto;
      padding: 10px 26px 20px;
      resize: none;
      color: var(--primary);
      caret-color: var(--accent);
      background: transparent;
      border: 0;
      outline: 0;
      font-size: var(--body-size);
      font-weight: var(--body-weight);
      line-height: 1.5;
      tab-size: 2;
    }

    #editor::selection {
      background: var(--selection);
    }

    #instructions {
      flex: 0 0 auto;
      margin: 0 26px;
      padding: 12px 0 15px;
      color: var(--secondary);
      border-top: 1px solid var(--divider);
      font-size: var(--footer-size);
      line-height: 1.25;
      user-select: none;
    }

    #instructions[hidden] {
      display: none;
    }
  </style>
</head>
<body>
  <main id="panel">
    <header id="title">Scratchpad</header>
    <textarea
      id="editor"
      aria-label="Gearbox scratchpad"
      autocomplete="off"
      autocorrect="off"
      autocapitalize="off"
      spellcheck="false"
      wrap="soft"
    ></textarea>
    <footer id="instructions">
      Cursor keys move · Tab inserts tabs
    </footer>
  </main>

  <script>
    (() => {
      const root = document.documentElement;
      const title = document.getElementById("title");
      const editor = document.getElementById("editor");
      const instructions = document.getElementById("instructions");
      let saveTimer = null;

      const post = (message) => {
        try {
          window.webkit.messageHandlers.gearboxScratchpad.postMessage(message);
        } catch (_) {
          // The bridge disappears while Hammerspoon is stopping or reloading.
        }
      };

      const saveSoon = () => {
        window.clearTimeout(saveTimer);
        saveTimer = window.setTimeout(() => {
          post({ action: "save", content: editor.value });
        }, 350);
      };

      editor.addEventListener("input", saveSoon);

      editor.addEventListener("keydown", (event) => {
        if (event.key === "Tab") {
          event.preventDefault();

          const selectionLength =
            editor.selectionEnd - editor.selectionStart;
          const nextLength =
            editor.value.length - selectionLength + 1;

          if (
            nextLength > editor.maxLength &&
            nextLength > editor.value.length
          ) {
            return;
          }

          editor.setRangeText(
            "\t",
            editor.selectionStart,
            editor.selectionEnd,
            "end"
          );
          saveSoon();
          return;
        }

      });

      window.GearboxScratchpad = {
        update(state) {
          const colors = state.colors;

          root.style.setProperty("--background", colors.background);
          root.style.setProperty("--primary", colors.primary);
          root.style.setProperty("--secondary", colors.secondary);
          root.style.setProperty("--divider", colors.divider);
          root.style.setProperty("--accent", colors.accent);
          root.style.setProperty("--selection", colors.selection);
          root.style.setProperty(
            "--corner-radius",
            `${state.cornerRadius}px`
          );
          root.style.setProperty("--body-size", `${state.bodySize}px`);
          root.style.setProperty("--title-size", `${state.titleSize}px`);
          root.style.setProperty("--footer-size", `${state.footerSize}px`);
          root.style.setProperty("--body-weight", state.bodyWeight);
          root.style.setProperty("--title-weight", state.titleWeight);

          title.style.fontFamily = state.fontFamily;
          editor.style.fontFamily = state.fontFamily;
          instructions.style.fontFamily = state.fontFamily;
          title.textContent = state.title;
          instructions.textContent = state.instructions;
          instructions.hidden = !state.showInstructions;
          editor.maxLength = state.maxCharacters;

          if (typeof state.content === "string") {
            editor.value = state.content;
          }
        },

        focus() {
          editor.focus({ preventScroll: true });
        },

        content() {
          return editor.value;
        },
      };
    })();
  </script>
</body>
</html>
]]

local function round(value)
  return math.floor(value + 0.5)
end

local function cssColor(color)
  local alpha = color.alpha or 1

  if color.white ~= nil then
    local component = round(color.white * 255)

    return ("rgba(%d, %d, %d, %.4f)"):format(
      component,
      component,
      component,
      alpha
    )
  end

  return ("rgba(%d, %d, %d, %.4f)"):format(
    round(color.red * 255),
    round(color.green * 255),
    round(color.blue * 255),
    alpha
  )
end

function Scratchpad.new(config, theme)
  local self = setmetatable({}, Scratchpad)

  self.config = config
  self.theme = theme
  self.webview = nil
  self.controller = nil
  self.ready = false
  self.appliedThemeId = nil

  local stored = config.scratchpad.persistContent
      and hs.settings.get(settingsKey)
      or nil

  self.content = type(stored) == "string" and stored or ""

  return self
end

function Scratchpad:menuItem()
  return {
    key = self.config.scratchpad.menuKey,
    label = "Scratchpad",
    kind = "action",
    action = {
      type = "openScratchpad",
    },
  }
end

function Scratchpad:targetScreen()
  if self.config.menu.screen == "mouse" then
    return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  end

  return hs.screen.mainScreen()
end

function Scratchpad:frame()
  local screen = assert(
    self:targetScreen(),
    "Gearbox: no screen is available for the scratchpad"
  )

  local screenFrame = screen:frame()
  local width = math.min(self.config.scratchpad.width, screenFrame.w)
  local height = math.min(self.config.scratchpad.height, screenFrame.h)
  local availableHeight = math.max(0, screenFrame.h - height)

  return {
    x = screenFrame.x + (screenFrame.w - width) / 2,
    y = screenFrame.y
        + availableHeight * verticalPositions[self.config.menu.position],
    w = width,
    h = height,
  }
end

function Scratchpad:state(includeContent)
  local bodyFont = self.theme.fonts.body
  local titleFont = self.theme.fonts.title
  local colors = self.theme.colors

  local state = {
    title = self.config.menu.showEmojis
        and "📝  Scratchpad"
        or "Scratchpad",
    fontFamily = bodyFont.name or "-apple-system",
    bodySize = bodyFont.size or self.config.font.size,
    titleSize = titleFont.size or self.config.font.titleSize,
    footerSize = math.max(11, (bodyFont.size or self.config.font.size) - 1),
    bodyWeight = self.config.font.bodyWeight == "bold" and 700 or 400,
    titleWeight = self.config.font.titleWeight == "bold" and 700 or 400,
    cornerRadius = self.theme.metrics.windowCornerRadius,
    showInstructions = self.config.scratchpad.showInstructions,
    maxCharacters = self.config.scratchpad.maxCharacters,
    instructions = "Cursor keys move · Tab inserts tabs · "
        .. table.concat(self.config.hotkey.modifiers, "+")
        .. "+"
        .. self.config.hotkey.key
        .. " closes scratchpad",
    colors = {
      background = cssColor(colors.background),
      primary = cssColor(colors.primary),
      secondary = cssColor(colors.secondary),
      divider = cssColor(colors.divider),
      accent = cssColor(colors.accent),
      selection = cssColor(colors.selection),
    },
  }

  if includeContent then
    state.content = self.content
  end

  return state
end

function Scratchpad:save(content)
  if type(content) ~= "string" then
    return
  end

  self.content = content

  if self.config.scratchpad.persistContent then
    hs.settings.set(settingsKey, content)
  end
end

function Scratchpad:handleMessage(message)
  if type(message) ~= "table" then
    return
  end

  if message.action == "save" then
    self:save(message.content)
  end
end

function Scratchpad:applyState(includeContent, focusEditor)
  if not self.webview or not self.ready then
    return
  end

  local encoded = hs.json.encode(self:state(includeContent))

  local script = "window.GearboxScratchpad.update(" .. encoded .. ");"

  if focusEditor then
    script = script .. "window.GearboxScratchpad.focus();"
  end

  self.webview:evaluateJavaScript(script)
  self.appliedThemeId = self.theme.activeThemeId
end

function Scratchpad:focusWindow()
  if not self.webview or not self.ready then
    return
  end

  self.webview:bringToFront()
  self.webview:hswindow():focus()
end

function Scratchpad:ensureView()
  if self.webview then
    return
  end

  self.controller = hs.webview.usercontent.new("gearboxScratchpad")
  self.controller:setCallback(function(message)
    self:handleMessage(message)
  end)

  self.webview = hs.webview.new(
    self:frame(),
    {
      developerExtrasEnabled = false,
      javaScriptCanOpenWindowsAutomatically = false,
      javaScriptEnabled = true,
    },
    self.controller
  )

  self.webview
      :windowStyle({})
      :allowTextEntry(true)
      :allowGestures(false)
      :allowNewWindows(false)
      :transparent(true)
      :shadow(true)
      :deleteOnClose(false)
      :navigationCallback(function(action)
        if action == "didFinishNavigation" then
          self.ready = true

          if self:isVisible() then
            self:focusWindow()
            self:applyState(true, true)
          else
            self:applyState(true, false)
          end
        end
      end)
      :html(document)
end

function Scratchpad:prepare()
  self.theme:refreshAppearance()
  self:ensureView()
end

function Scratchpad:isVisible()
  return self.webview ~= nil and self.webview:isVisible()
end

function Scratchpad:show()
  self.theme:refreshAppearance()
  self:ensureView()
  self.webview:frame(self:frame())
  self.webview:show()

  if self.ready then
    self:focusWindow()

    if self.appliedThemeId == self.theme.activeThemeId then
      self.webview:evaluateJavaScript(
        "window.GearboxScratchpad.focus();"
      )
    else
      self:applyState(false, true)
    end
  end
end

function Scratchpad:hide()
  if not self.webview then
    return
  end

  if self.ready and self.config.scratchpad.persistContent then
    self.webview:evaluateJavaScript(
      "window.GearboxScratchpad.content();",
      function(content)
        self:save(content)
      end
    )
  end

  self.webview:hide()
end

function Scratchpad:delete()
  if self.webview then
    self:hide()
    self.webview:delete()
    self.webview = nil
  end

  if self.controller then
    self.controller:setCallback(nil)
    self.controller = nil
  end

  self.ready = false
  self.appliedThemeId = nil
end

return Scratchpad
