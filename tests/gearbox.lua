local root = assert(arg[1], "repository root argument is required")

package.path = root .. "/?.lua;"
    .. root .. "/?/init.lua;"
    .. package.path

local caffeinateState = {
  displayIdle = false,
  systemIdle = false,
}

local createdModals = {}
local createdWebviews = {}
local createdWebviewControllers = {}
local globalHotkeyPressed
local launchedApplication
local defaultTextStyleCalls = 0
local failNextModalBind = false
local failNextGlobalHotkey = false
local interfaceStyle = "Dark"
local interfaceStyleCalls = 0
local osascriptCalls = 0
local reloadCalls = 0
local settings = {}

local function newModal()
  local modal = {
    bindings = {},
    bindingCalls = {},
  }

  function modal:bind(
    modifiers,
    key,
    message,
    pressed,
    released,
    repeated
  )
    if failNextModalBind then
      failNextModalBind = false
      error("simulated modal binding failure")
    end

    if message == nil or type(message) == "function" then
      repeated = released
      released = pressed
      pressed = message
      message = nil
    end

    table.insert(self.bindingCalls, {
      modifiers = modifiers,
      key = key,
      pressed = pressed,
      released = released,
      repeated = repeated,
    })

    self.bindings[key] = pressed or released or repeated
    return self
  end

  function modal:enter()
    if self.entered then
      self.entered()
    end
    return self
  end

  function modal:exit()
    if self.exited then
      self.exited()
    end
    return self
  end

  function modal:delete()
    self.deleted = true
  end

  return modal
end

local function newCanvas()
  local canvas = {
    elements = {},
  }

  function canvas:appendElements(elements)
    self.elements = elements
    return self
  end

  function canvas:elementAttribute(index, attribute, value)
    self.elements[index][attribute] = value
    return self
  end

  function canvas:wantsLayer()
    return self
  end

  function canvas:show()
    self.visible = true
    return self
  end

  function canvas:delete()
    self.visible = false
  end

  return canvas
end

local function newWebview(frame, controller)
  local webview = {
    currentFrame = frame,
    controller = controller,
    evaluatedScripts = {},
    visible = false,
  }

  local function chain(name)
    webview[name] = function(self, value)
      self[name .. "Value"] = value
      return self
    end
  end

  for _, name in ipairs({
    "allowGestures",
    "allowNewWindows",
    "allowTextEntry",
    "deleteOnClose",
    "shadow",
    "transparent",
    "windowStyle",
  }) do
    chain(name)
  end

  function webview:bringToFront()
    self.broughtToFront = true
    return self
  end

  function webview:delete()
    self.deleted = true
    self.visible = false
  end

  function webview:evaluateJavaScript(script, callback)
    table.insert(self.evaluatedScripts, script)

    if callback then
      callback(self.contentResult, nil)
    end

    return self
  end

  function webview:frame(value)
    if value then
      self.currentFrame = value
      return self
    end

    return self.currentFrame
  end

  function webview:hide()
    self.visible = false
    return self
  end

  function webview:hswindow()
    return {
      focus = function()
        self.focused = true
      end,
    }
  end

  function webview:html(value)
    self.document = value

    if self.navigationCallbackValue then
      self.navigationCallbackValue(
        "didFinishNavigation",
        self,
        "mock-navigation"
      )
    end

    return self
  end

  function webview:isVisible()
    return self.visible
  end

  function webview:navigationCallback(callback)
    self.navigationCallbackValue = callback
    return self
  end

  function webview:show()
    self.visible = true
    return self
  end

  table.insert(createdWebviews, webview)
  return webview
end

hs = {
  alert = {
    show = function() end,
  },

  application = {
    launchOrFocus = function(name)
      launchedApplication = name
    end,
  },

  canvas = {
    defaultTextStyle = function()
      defaultTextStyleCalls = defaultTextStyleCalls + 1

      return {
        font = {
          name = "System",
          size = 14,
        },
      }
    end,
    new = function()
      return newCanvas()
    end,
  },

  caffeinate = {
    get = function(kind)
      return caffeinateState[kind]
    end,
    set = function(kind, value)
      caffeinateState[kind] = value
    end,
    systemSleep = function() end,
  },

  fs = {
    dir = function(path)
      local process = assert(io.popen(("/bin/ls -a1 %q"):format(path)))
      local closed = false

      return function()
        local file = process:read("*l")

        if not file and not closed then
          process:close()
          closed = true
        end

        return file
      end
    end,
  },

  hotkey = {
    bind = function(_, _, callback)
      if failNextGlobalHotkey then
        failNextGlobalHotkey = false
        return nil
      end

      globalHotkeyPressed = callback
      return {
        delete = function(self)
          self.deleted = true
        end,
      }
    end,
    modal = {
      new = function()
        local modal = newModal()
        table.insert(createdModals, modal)
        return modal
      end,
    },
  },

  host = {
    interfaceStyle = function()
      interfaceStyleCalls = interfaceStyleCalls + 1
      return interfaceStyle
    end,
  },

  json = {
    decode = function(value)
      if value == "system-accent" then
        return {
          red = 0.2,
          green = 0.3,
          blue = 0.4,
          alpha = 1,
        }
      end

      return nil
    end,
    encode = function()
      return "{}"
    end,
  },

  keycodes = {
    map = setmetatable(
      {
        down = 125,
        escape = 53,
        ["return"] = 36,
        space = 49,
        up = 126,
      },
      {
        __index = function(_, key)
          if key:match("^[a-z0-9]$") then
            return 1
          end
        end,
      }
    ),
  },

  mouse = {
    getCurrentScreen = function()
      return nil
    end,
  },

  open = function()
    return true
  end,

  reload = function()
    reloadCalls = reloadCalls + 1
  end,

  osascript = {
    javascript = function()
      osascriptCalls = osascriptCalls + 1
      return true, "system-accent"
    end,
  },

  screen = {
    mainScreen = function()
      return {
        frame = function()
          return {
            x = 0,
            y = 0,
            w = 1920,
            h = 1080,
          }
        end,
      }
    end,
  },

  settings = {
    clear = function(key)
      settings[key] = nil
    end,
    get = function(key)
      return settings[key]
    end,
    set = function(key, value)
      settings[key] = value
    end,
  },

  styledtext = {
    convertFont = function(font)
      return font
    end,
    new = function(text)
      return text
    end,
    validFont = function()
      return true
    end,
  },

  timer = {
    absoluteTime = function()
      return 0
    end,
    doAfter = function()
      return {
        stop = function() end,
      }
    end,
    doEvery = function()
      return {
        stop = function() end,
      }
    end,
  },

  webview = {
    new = function(frame, _, controller)
      return newWebview(frame, controller)
    end,
    usercontent = {
      new = function(name)
        local controller = {
          name = name,
        }

        function controller:setCallback(callback)
          self.callback = callback
          return self
        end

        table.insert(createdWebviewControllers, controller)
        return controller
      end,
    },
  },
}

local Actions = require("Spoons.Gearbox.actions")
local Loader = require("Spoons.Gearbox.loader")
local Theme = require("Spoons.Gearbox.theme")
local config = require("Spoons.Gearbox.config")

assert(
  config.loupe.selectedScale == 1.18
      and config.loupe.duration == 0,
  "standalone loupe defaults must retain immediate navigation"
)
assert(
  config.scratchpad.enable
      and config.scratchpad.menuKey == "p"
      and config.scratchpad.width == 720
      and config.scratchpad.height == 480
      and config.scratchpad.maxCharacters == 4096,
  "standalone scratchpad defaults changed"
)

local discoveredTheme = Theme.new(
  config,
  root .. "/Spoons/Gearbox"
)

local menus, rootId = Loader.load(
  root .. "/Spoons/Gearbox",
  config,
  Actions,
  { discoveredTheme:menuDefinition() },
  discoveredTheme
)

assert(rootId == "leader", "leader must be the root menu")
assert(menus.leader.title == "Gearbox", "leader title changed")

local function rowShape(menu)
  local rows = {}

  for _, row in ipairs(menu.rows) do
    table.insert(rows, row.divider and "|" or row.key)
  end

  return table.concat(rows, ",")
end

assert(
  rowShape(menus.leader)
      == "c,l,k,s,|,n,a,d,f,w,|,m,t,|,escape",
  "leader ordering or divider placement changed"
)

assert(
  rowShape(menus.browsers) == "b,s,|,escape",
  "browser menu shape changed"
)

assert(
  rowShape(menus.macos) == "h,e,|,a,i,x,|,s,|,escape",
  "macOS Utilities menu shape changed"
)

assert(
  rowShape(menus.themes)
      == "s,|,a,l,g,|,c,r,d,h,m,n,t,|,escape",
  "Themes menu shape changed"
)

local themeLabels = {}

for _, row in ipairs(menus.themes.rows) do
  if not row.divider then
    themeLabels[row.key] = row.label
  end
end

assert(themeLabels.l == "Gearbox Light", "light theme label changed")
assert(themeLabels.d == "Gearbox Dark", "dark theme label changed")
assert(
  menus.leader.rows[#menus.leader.rows].label:match("^Exit Gearbox"),
  "leader footer changed"
)

local themeCount = 0

for _ in pairs(discoveredTheme.themes) do
  themeCount = themeCount + 1
end

assert(themeCount == 10, "all bundled themes must be discovered")

local modalCountBeforeInvalidDefinitions = #createdModals

local missingThemeActionAccepted = pcall(function()
  Loader.load(
    root .. "/Spoons/Gearbox",
    config,
    Actions,
    {
      {
        id = "missing-theme-action",
        title = "Missing Theme Action",
        parent = "leader",
        entry = {
          key = "y",
          label = "Missing Theme Action",
        },
        items = {
          {
            key = "q",
            label = "Missing",
            kind = "action",
            action = {
              type = "setTheme",
              theme = "missing",
            },
          },
        },
      },
    },
    discoveredTheme
  )
end)

assert(
  not missingThemeActionAccepted,
  "setTheme actions must reference a discovered theme"
)
assert(
  #createdModals == modalCountBeforeInvalidDefinitions,
  "action validation must finish before modals are allocated"
)

local duplicateChildAccepted = pcall(function()
  Loader.load(
    root .. "/Spoons/Gearbox",
    config,
    Actions,
    {
      {
        id = "duplicate-child-key",
        title = "Duplicate Child Key",
        parent = "leader",
        entry = {
          key = "c",
          label = "Duplicate Child Key",
        },
        items = {},
      },
    },
    discoveredTheme
  )
end)

assert(not duplicateChildAccepted, "item and child keys must not collide")
assert(
  #createdModals == modalCountBeforeInvalidDefinitions,
  "menu assembly must finish before modals are allocated"
)

local modeActions = {}

for _, row in ipairs(menus.macos.rows) do
  if row.checkable then
    modeActions[row.key] = row.action
  end
end

local function checkedKey()
  local checked = {}
  local currentMode = Actions.currentCaffeinateMode()

  for key, action in pairs(modeActions) do
    if action.mode == currentMode then
      table.insert(checked, key)
    end
  end

  table.sort(checked)
  return table.concat(checked, ",")
end

local context = {
  exit = function() end,
  openMenu = function() end,
}

assert(checkedKey() == "x", "normal sleep must be checked by default")

Actions.execute(modeActions.a, context)
assert(checkedKey() == "a", "display mode must be the only checked mode")

Actions.execute(modeActions.i, context)
assert(checkedKey() == "i", "idle mode must be the only checked mode")

Actions.execute(modeActions.x, context)
assert(checkedKey() == "x", "normal mode must clear both assertions")

local reloadResult = Actions.execute({ type = "reload" }, context)
assert(reloadCalls == 1, "reload action must reload Hammerspoon")
assert(reloadResult.handled == true, "reload action must stop runtime processing")

defaultTextStyleCalls = 0
interfaceStyleCalls = 0
osascriptCalls = 0
settings = {}

settings["Shift7.theme.selection"] = {
  selection = "shift7-dark",
  configuredDefault = "system",
}
settings["Gearbox.scratchpad.content"] = "restored draft"

local Gearbox = require("Spoons.Gearbox")
local runtime = Gearbox.start({
  theme = {
    accentSource = "theme",
    overrides = {
      ["gearbox-dark"] = {
        accent = {
          white = 0.5,
        },
        background = {
          red = 0.05,
          green = 0.06,
          blue = 0.07,
        },
      },
    },
  },
})

assert(
  settings["Shift7.theme.selection"] == nil,
  "legacy persistence key must be cleared after activation"
)
assert(
  settings["Gearbox.theme.selection"].selection == "gearbox-dark"
      and settings["Gearbox.theme.selection"].configuredDefault == "system",
  "legacy persistence must migrate built-in theme IDs"
)

assert(type(globalHotkeyPressed) == "function", "global hotkey was not registered")
assert(
  interfaceStyleCalls == 0,
  "system appearance must remain lazy until a menu opens"
)

globalHotkeyPressed()
assert(runtime.activeMenu.id == "leader", "global hotkey must open leader")
assert(
  interfaceStyleCalls == 0,
  "a migrated manual theme must not resolve system appearance"
)

assert(
  runtime.hud.theme.colors.background.white == nil
      and runtime.hud.theme.colors.background.red == 0.05,
  "RGB overrides must replace a grayscale color model"
)

assert(
  runtime.hud.theme.colors.background.alpha == 0.96,
  "color-model replacement must retain the default alpha"
)

assert(
  runtime.hud.theme.colors.selection.white == 0.5
      and runtime.hud.theme.colors.selection.red == nil
      and runtime.hud.theme.colors.selection.alpha == 0.22,
  "selection colors must preserve grayscale accent overrides"
)

assert(
  runtime.theme.activeThemeId == "gearbox-dark",
  "migrated dark selection must resolve the Gearbox dark theme"
)
assert(
  runtime.scratchpad.content == "restored draft",
  "scratchpad must restore persisted content"
)
assert(
  #createdWebviews == 1 and not createdWebviews[1].visible,
  "scratchpad webview must be prewarmed before its first invocation"
)
assert(
  runtime.hud.canvas.elements[1].roundedRectRadii.xRadius
      == runtime.theme.metrics.windowCornerRadius,
  "menu HUD and scratchpad must share the outer corner radius"
)

assert(
  defaultTextStyleCalls == 1,
  "system font defaults must be resolved once per theme"
)

assert(osascriptCalls == 0, "theme accents must not resolve the system accent")

local function findBinding(modal, key, modifiers)
  local expectedModifiers = table.concat(modifiers, "+")

  for _, binding in ipairs(modal.bindingCalls) do
    if binding.key == key
        and table.concat(binding.modifiers, "+") == expectedModifiers then
      return binding
    end
  end
end

local rootModal = runtime.menus.leader.modal

assert(
  findBinding(rootModal, "d", config.hotkey.modifiers),
  "item keys must accept the retained leader modifiers"
)

assert(
  not findBinding(rootModal, "escape", config.hotkey.modifiers),
  "Escape must not shadow the native modified shortcut"
)

assert(
  not findBinding(rootModal, "down", config.hotkey.modifiers),
  "navigation arrows must not shadow modified system shortcuts"
)

assert(
  not findBinding(rootModal, "return", config.hotkey.modifiers),
  "Return activation must be bound without leader modifiers"
)

local downBinding = assert(findBinding(rootModal, "down", {}))

assert(
  downBinding.pressed and downBinding.repeated,
  "arrow navigation must run on key press and key repeat"
)

runtime.menus.leader.modal.bindings.down()
assert(
  runtime.menus.leader.selectedIndex == 1,
  "first Down press must select the first entry"
)

runtime.menus.leader.modal.bindings["return"]()
assert(launchedApplication == "Calculator", "Return must activate selected entry")
assert(runtime.activeMenu == nil, "application launch must close Gearbox")

globalHotkeyPressed()
runtime.menus.leader.modal.bindings.p()

assert(runtime.activeMenu == nil, "scratchpad must replace the menu HUD")
assert(#createdWebviews == 1, "scratchpad must reuse its prewarmed webview")
assert(
  createdWebviewControllers[1].name == "gearboxScratchpad",
  "scratchpad must use its private message bridge"
)
assert(createdWebviews[1].visible, "scratchpad action must show the webview")
assert(
  createdWebviews[1].allowTextEntryValue == true
      and createdWebviews[1].transparentValue == true
      and createdWebviews[1].shadowValue == true
      and #createdWebviews[1].windowStyleValue == 0,
  "scratchpad must be an editable, transparent, borderless panel"
)
assert(
  createdWebviews[1].currentFrame.w == 720
      and createdWebviews[1].currentFrame.h == 480
      and createdWebviews[1].currentFrame.x == 600
      and createdWebviews[1].currentFrame.y == 150,
  "scratchpad must use configured size and Gearbox placement"
)
assert(
  createdWebviews[1].document:match("Tab inserts tabs"),
  "scratchpad must include the non-editable instructions"
)
assert(
  not createdWebviews[1].document:match('event.key === "Escape"'),
  "scratchpad must not bind Escape"
)

local scratchpadState = runtime.scratchpad:state(false)

assert(
  scratchpadState.instructions
      == "Cursor keys move · Tab inserts tabs · alt+cmd+space closes scratchpad",
  "scratchpad instructions must include the configured Gearbox hotkey"
)
assert(
  scratchpadState.footerSize == 13,
  "scratchpad instructions must remain subtle but legible"
)
assert(
  scratchpadState.maxCharacters == 4096
      and createdWebviews[1].document:match(
        "editor.maxLength = state.maxCharacters"
      ),
  "scratchpad must expose its configured capacity to the native editor"
)

createdWebviewControllers[1].callback({
  action = "save",
  content = "persistent draft",
})

assert(
  settings["Gearbox.scratchpad.content"] == "persistent draft",
  "scratchpad content must persist through hs.settings"
)

createdWebviews[1].contentResult = "persistent draft"
globalHotkeyPressed()
assert(
  not createdWebviews[1].visible,
  "global Gearbox hotkey must hide the scratchpad"
)

globalHotkeyPressed()
runtime.menus.leader.modal.bindings.p()
assert(
  #createdWebviews == 1 and createdWebviews[1].visible,
  "scratchpad must reuse its existing webview"
)

createdWebviews[1].contentResult = "reopened draft"
globalHotkeyPressed()

assert(
  not createdWebviews[1].visible
      and settings["Gearbox.scratchpad.content"] == "reopened draft",
  "Gearbox hotkey must save and hide the reopened scratchpad"
)

globalHotkeyPressed()
runtime.menus.leader.modal.bindings.m()
assert(runtime.activeMenu.id == "macos", "m must open macOS Utilities")

local styleCallsBeforeHUDRefresh = interfaceStyleCalls

runtime.menus.macos.modal.bindings.a()
assert(
  Actions.currentCaffeinateMode() == "display",
  "display mode action must remain active after HUD refresh"
)
assert(
  runtime.activeMenu.id == "macos",
  "changing a power mode must keep macOS Utilities open"
)
assert(
  interfaceStyleCalls == styleCallsBeforeHUDRefresh,
  "HUD-only refreshes must not resolve system appearance"
)

runtime.menus.macos.modal.bindings.escape()
runtime.menus.leader.modal.bindings.t()
assert(runtime.activeMenu.id == "themes", "t must open Themes")

local function checkedThemeKeys()
  local checked = runtime:checkedRows(runtime.menus.themes)
  local keys = {}

  for index, row in ipairs(runtime.menus.themes.rows) do
    if checked[index] then
      table.insert(keys, row.key)
    end
  end

  return table.concat(keys, ",")
end

assert(checkedThemeKeys() == "d", "migrated theme must be the only checked selector")

local styleCallsBeforeThemePreview = interfaceStyleCalls

runtime.menus.themes.modal.bindings.c()

assert(
  runtime.theme.selection == "catppuccin-mocha",
  "theme action must update the selected theme"
)
assert(
  runtime.theme.activeThemeId == "catppuccin-mocha",
  "theme action must immediately apply its palette"
)
assert(
  runtime.theme.colors.accent.red == 0.796078,
  "theme accent source must use the selected preset"
)
assert(
  interfaceStyleCalls == styleCallsBeforeThemePreview,
  "manual theme previews must not resolve system appearance"
)
assert(checkedThemeKeys() == "c", "only the selected theme must be checked")
assert(
  settings["Gearbox.theme.selection"].selection == "catppuccin-mocha",
  "theme selections must persist"
)

interfaceStyle = nil
runtime.menus.themes.modal.bindings.s()

assert(runtime.theme.selection == "system", "system selection must be restored")
assert(
  runtime.theme.activeThemeId == "gearbox-light",
  "system selection must resolve the light appearance"
)
assert(checkedThemeKeys() == "s", "system must regain the exclusive check")

interfaceStyle = "Dark"
runtime.menus.themes.modal.bindings.escape()

assert(
  runtime.theme.activeThemeId == "gearbox-dark",
  "modal entry must re-evaluate the system appearance"
)

runtime.menus.leader.modal.bindings.t()
runtime.menus.themes.modal.bindings.r()

assert(
  runtime.theme.selection == "dracula",
  "manual selection must switch away from system mode"
)

local validRuntime = runtime
local mixedColorAccepted = pcall(function()
  Gearbox.start({
    theme = {
      overrides = {
        dracula = {
          background = {
            white = 0.1,
            red = 0.1,
            green = 0.1,
            blue = 0.1,
          },
        },
      },
    },
  })
end)

assert(not mixedColorAccepted, "mixed grayscale and RGB colors must fail")
assert(validRuntime.started, "invalid overrides must not stop the active runtime")
assert(
  validRuntime.activeMenu.id == "themes",
  "invalid overrides must preserve the active menu"
)

local unknownThemeAccepted = pcall(function()
  Gearbox.start({
    theme = {
      overrides = {
        missing = {
          selectionAlpha = 0.2,
        },
      },
    },
  })
end)

assert(not unknownThemeAccepted, "unknown theme overrides must fail")
assert(validRuntime.started, "unknown overrides must preserve active runtime")

local unknownFieldAccepted = pcall(function()
  Gearbox.start({
    theme = {
      overrides = {
        dracula = {
          unknown = 1,
        },
      },
    },
  })
end)

assert(not unknownFieldAccepted, "unknown theme override fields must fail")
assert(validRuntime.started, "unknown fields must preserve active runtime")

local invalidKeyAccepted = pcall(function()
  Gearbox.start({
    hotkey = {
      key = "not-a-real-key",
    },
  })
end)

assert(not invalidKeyAccepted, "invalid Hammerspoon keys must fail early")
assert(validRuntime.started, "invalid keys must not stop the active runtime")
assert(
  validRuntime.activeMenu.id == "themes",
  "invalid keys must preserve the active menu"
)

local reservedCaseAccepted = pcall(function()
  Gearbox.start({
    navigation = {
      activateKey = "Down",
    },
  })
end)

assert(
  not reservedCaseAccepted,
  "reserved navigation keys must be compared case-insensitively"
)
assert(
  validRuntime.activeMenu.id == "themes",
  "reserved key failures must preserve the active menu"
)

local smallScratchpadAccepted = pcall(function()
  Gearbox.start({
    scratchpad = {
      width = 359,
    },
  })
end)

assert(
  not smallScratchpadAccepted,
  "undersized scratchpad dimensions must fail early"
)
assert(
  validRuntime.activeMenu.id == "themes",
  "scratchpad validation failures must preserve the active menu"
)

local invalidScratchpadCapacityAccepted = pcall(function()
  Gearbox.start({
    scratchpad = {
      maxCharacters = 0,
    },
  })
end)

assert(
  not invalidScratchpadCapacityAccepted,
  "scratchpad capacity must be a positive integer"
)
assert(
  validRuntime.activeMenu.id == "themes",
  "scratchpad capacity failures must preserve the active menu"
)

local duplicateScratchpadKeyAccepted = pcall(function()
  Gearbox.start({
    scratchpad = {
      menuKey = "c",
    },
  })
end)

assert(
  not duplicateScratchpadKeyAccepted,
  "scratchpad menu keys must not collide with root entries"
)
assert(
  validRuntime.activeMenu.id == "themes",
  "scratchpad key failures must preserve the active menu"
)

local fontCallsBeforePartialStart = defaultTextStyleCalls
local partialStartModalIndex = #createdModals + 1
failNextModalBind = true

local partialStartAccepted = pcall(function()
  Gearbox.start({
    theme = {
      accentSource = "theme",
    },
  })
end)

assert(not partialStartAccepted, "partial modal registration must fail startup")

for index = partialStartModalIndex, #createdModals do
  assert(
    createdModals[index].deleted,
    "partial startup must delete every candidate modal"
  )
end

assert(validRuntime.started, "partial startup must preserve the active runtime")
assert(
  defaultTextStyleCalls == fontCallsBeforePartialStart + 1,
  "a failed candidate must resolve fonts only once"
)
assert(
  validRuntime.activeMenu.id == "themes",
  "partial startup must preserve the active menu"
)

local fontCallsBeforeGlobalFailure = defaultTextStyleCalls
local globalFailureModalIndex = #createdModals + 1
failNextGlobalHotkey = true

local unavailableHotkeyAccepted = pcall(function()
  Gearbox.start({
    theme = {
      name = "gearbox-light",
      accentSource = "theme",
    },
  })
end)

assert(
  not unavailableHotkeyAccepted,
  "unavailable global hotkeys must fail startup"
)
assert(
  validRuntime.started,
  "failed hotkey registration must not stop the active runtime"
)
assert(
  validRuntime.activeMenu.id == "themes",
  "failed hotkey registration must preserve the active menu"
)
assert(
  defaultTextStyleCalls == fontCallsBeforeGlobalFailure + 1,
  "an unavailable hotkey candidate must resolve fonts only once"
)

for index = globalFailureModalIndex, #createdModals do
  assert(
    createdModals[index].deleted,
    "failed hotkey registration must delete every candidate modal"
  )
end

assert(
  settings["Gearbox.theme.selection"].selection == "dracula"
      and settings["Gearbox.theme.selection"].configuredDefault == "system",
  "failed replacement must not clear the active persisted selection"
)

local fontCallsBeforeReplacements = defaultTextStyleCalls

local replacementRuntime = Gearbox.start({
  theme = {
    accentSource = "theme",
  },
})

assert(replacementRuntime.started, "replacement runtime must start")
assert(
  replacementRuntime.theme.selection == "dracula",
  "a valid persisted selection must survive reload"
)
assert(
  not validRuntime.started,
  "successful replacement must stop the previous runtime"
)

local configuredRuntime = Gearbox.start({
  theme = {
    name = "gearbox-light",
    accentSource = "theme",
  },
})

assert(
  configuredRuntime.theme.selection == "gearbox-light",
  "a changed configured default must invalidate persisted selection"
)
assert(
  settings["Gearbox.theme.selection"] == nil,
  "invalidated persisted selection must be cleared"
)

settings["Gearbox.theme.selection"] = {
  selection = "removed-theme",
  configuredDefault = "gearbox-light",
}

local missingThemeRuntime = Gearbox.start({
  theme = {
    name = "gearbox-light",
    accentSource = "theme",
  },
})

assert(
  missingThemeRuntime.theme.selection == "gearbox-light",
  "a missing persisted theme must fall back to configuration"
)
assert(
  settings["Gearbox.theme.selection"] == nil,
  "a missing persisted theme must be cleared"
)

settings["Gearbox.theme.selection"] = {
  selection = "dracula",
  configuredDefault = "gearbox-light",
}

local nonPersistentRuntime = Gearbox.start({
  theme = {
    name = "gearbox-light",
    persistSelection = false,
    accentSource = "theme",
  },
})

assert(
  nonPersistentRuntime.theme.selection == "gearbox-light",
  "disabled persistence must use configured selection"
)
assert(
  settings["Gearbox.theme.selection"] == nil,
  "disabled persistence must clear stored selection"
)

assert(
  defaultTextStyleCalls == fontCallsBeforeReplacements + 4,
  "each replacement must resolve fonts once and modal refreshes never should"
)

local accentCallsBefore = osascriptCalls
local systemAccentRuntime = Gearbox.start({
  theme = {
    name = "gearbox-dark",
    persistSelection = false,
    accentSource = "system",
  },
})

assert(
  osascriptCalls == accentCallsBefore + 1,
  "system accent must resolve once during startup"
)

globalHotkeyPressed()

assert(
  systemAccentRuntime.theme.colors.accent.red == 0.2,
  "system accent source must use the resolved macOS accent"
)

local noScratchpadRuntime = Gearbox.start({
  scratchpad = {
    enable = false,
  },
  theme = {
    accentSource = "theme",
  },
})

assert(
  noScratchpadRuntime.menus.leader.modal.bindings.p == nil,
  "disabled scratchpad must not register a root-menu key"
)

Gearbox.stop()

print("Gearbox smoke test passed")
