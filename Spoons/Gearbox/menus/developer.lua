--- Developer tools submenu: Codex, Sublime Merge, VirtualBuddy, Zed.
return {
  id = "developer",
  title = "Developer Tools",
  emoji = "🛠️",
  parent = "leader",

  entry = { key = "D", label = "Developer Tools" },

  items = {
    {
      key = "c",
      label = "Codex",
      kind = "application",
      action = { type = "launchApp", name = "Codex" }
    }, {
    key = "e",
    label = "Echolot",
    kind = "application",
    action = { type = "launchApp", name = "Echolot" }
  }, {
    key = "y",
    label = "Hypervisaur",
    kind = "application",
    action = { type = "launchApp", name = "Hypervisaur" }
  }, {
    key = "m",
    label = "MacVisor",
    kind = "application",
    action = { type = "launchApp", name = "MacVisor" }
  }, {
    key = "v",
    label = "Retriever",
    kind = "application",
    action = { type = "launchApp", name = "Retriever" }
  }, {
    key = "r",
    label = "Rockxy",
    kind = "application",
    action = { type = "launchApp", name = "Rockxy" }
  }, {
    key = "s",
    label = "Sloth",
    kind = "application",
    action = { type = "launchApp", name = "Sloth" }
  }, {
    key = "g",
    label = "Stargazer",
    kind = "application",
    action = { type = "launchApp", name = "Stargazer" }
  }, {
    key = "a",
    label = "TablePlus",
    kind = "application",
    action = { type = "launchApp", name = "TablePlus" }
  }, {
    key = "t",
    label = "Tracexy",
    kind = "application",
    action = { type = "launchApp", name = "Tracexy" }
  }, {
    key = "x",
    label = "Xcode",
    kind = "application",
    action = { type = "launchApp", name = "Xcode" }
  }
  }
}
