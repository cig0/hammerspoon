return {
  id = "finder",
  title = "Finder Folders",
  emoji = "📁",
  parent = "leader",

  entry = {
    key = "f",
    label = "Finder Folders",
  },

  items = {
    {
      key = "e",
      label = "Desktop",
      kind = "action",
      action = {
        type = "openPath",
        path = "~/Desktop",
      },
    },
    {
      key = "o",
      label = "Documents",
      kind = "action",
      action = {
        type = "openPath",
        path = "~/Documents",
      },
    },
    {
      key = "d",
      label = "Downloads",
      kind = "action",
      action = {
        type = "openPath",
        path = "~/Downloads",
      },
    },
    {
      key = "h",
      label = "Home (~/)",
      kind = "action",
      action = {
        type = "openPath",
        path = "~/",
      },
    },
  },
}
