--- Gearbox configuration.
--
-- Defaults for standalone use. Nix substitutes its exposed options when staging
-- this file; preferences.lua then applies the profile and local overrides.
-- Menu rows live in menus/*.lua; global app/menu shortcuts live in hyperkeys.lua.
return {
  hotkey = { modifiers = { "ctrl", "alt", "cmd" }, key = "space" },

  capsLockViaF18 = false,
  quickLaunch = require("Spoons.Gearbox.hyperkeys"),

  menu = {
    timeout = 0,          -- Zero is invalid and prevents Gearbox from starting; set a positive value (for example, 5) in Spoons/Gearbox/config.lua or via Gearbox Configuration → Menu Timeout (presets: 5, 10, 15, 20, 30, 60s).
    position = "top",     -- "top", "center", "bottom"
    screen = "main",      -- "main", "mouse"
    width = 420,

    showEmojis = true,
    highlightGroups = true,     -- Applies at every submenu depth.
    showAccentBorder = true,
    showWindowShadow = true,
    backgroundOpacity = 100      -- Menu background only, from 50 to 100 in steps of 5.
  },

  font = {
    family = nil,     -- nil uses the macOS system font.
    size = 14,
    titleSize = 20,

    bodyWeight = "regular",
    groupWeight = "bold",
    titleWeight = "bold"
  },

  loupe = {
    enabled = true,
    selectedScale = 1.18,
    adjacentScale = 1.06,
    duration = 0
  },

  theme = {
    name = "system",
    persistSelection = true,

    system = { dark = "gruvbox-dark-hard", light = "acidbox-light" },

    accentSource = "system",     -- "system", "theme"

    fallbackAccent = { red = 0.04, green = 0.48, blue = 1, alpha = 1 },

    systemAccentText = { white = 1, alpha = 1 },
    overrides = {}
  },

  navigation = {
    enabled = true,
    wrap = true,
    activateKey = "return",
    cancelKey = "escape",
    includeFooter = true,
    resetTimeoutOnInput = true
  },

  scratchpad = {
    enable = true,
    fontSize = 14,
    width = 720,
    height = 480,
    maxCharacters = 4096,
    persistContent = true,
    -- nil uses local hs.settings; /path or ~/path uses a regular text file.
    storagePath = nil,
    showInstructions = true
  }
}
