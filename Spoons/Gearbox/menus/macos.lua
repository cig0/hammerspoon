return {
  id = "macos",
  title = "macOS Utilities",
  emoji = "🍎",
  parent = "leader",

  entry = {
    key = "m",
    label = "macOS Utilities",
    section = "utilities",
    sectionOrder = 200,
    order = 10,
  },

  items = {
    {
      key = "a",
      label = "Keep Display Awake",
      kind = "action",
      action = {
        type = "setCaffeinateMode",
        mode = "display",
      },
    },
    {
      key = "i",
      label = "Prevent Idle Sleep",
      kind = "action",
      action = {
        type = "setCaffeinateMode",
        mode = "idle",
      },
    },
    {
      key = "x",
      label = "Allow Normal Sleep",
      kind = "action",
      action = {
        type = "setCaffeinateMode",
        mode = "normal",
      },
    },

    { divider = true },

    {
      key = "s",
      label = "Sleep",
      kind = "action",
      action = {
        type = "sleep",
      },
    },
  },
}
