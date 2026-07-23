--- Default Gearbox configuration.
--
-- User-facing defaults. This module contains no Hammerspoon calls; overrides
-- passed to `Gearbox.start()` are merged on top.
return {
  hotkey = {
    modifiers = { "alt", "cmd" },
    key = "space",
  },

  menu = {
    timeout = 0,      -- Set to 0 to disable.
    position = "top", -- "top", "center", "bottom"
    screen = "main",  -- "main", "mouse"
    width = 420,

    showEmojis = true,
    highlightGroups = true,
  },

  font = {
    family = nil, -- nil uses the macOS system font.
    size = 14,
    titleSize = 20,

    bodyWeight = "regular",
    groupWeight = "bold",
    titleWeight = "bold",
  },

  loupe = {
    enabled = true,
    selectedScale = 1.18,
    adjacentScale = 1.06,
    duration = 0,
  },

  theme = {
    name = "system",
    persistSelection = true,

    system = {
      dark = "gearbox-dark",
      light = "gearbox-light",
    },

    accentSource = "system", -- "system", "theme"

    fallbackAccent = {
      red = 0.04,
      green = 0.48,
      blue = 1,
      alpha = 1,
    },

    systemAccentText = { white = 1, alpha = 1 },
    overrides = {},
  },

  navigation = {
    enabled = true,
    wrap = true,
    activateKey = "return",
    cancelKey = "escape",
    includeFooter = true,
    resetTimeoutOnInput = true,
  },

  scratchpad = {
    enable = true,
    width = 720,
    height = 480,
    maxCharacters = 4096,
    persistContent = true,
    showInstructions = true,
  },
}
