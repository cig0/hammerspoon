--- Web browsers submenu: Brave Origin, ChatGPT Atlas, Comet, Firefox, Safari.
return {
  id = "browsers",
  title = "Web Browsers",
  emoji = "🌐",
  parent = "leader",

  entry = { key = "W", label = "Web Browsers" },

  items = {
    {
      key = "o",
      label = "Brave Origin",
      kind = "application",
      action = { type = "launchApp", name = "Brave Origin" }
    }, {
    key = "f",
    label = "Firefox",
    kind = "application",
    action = { type = "launchApp", name = "Firefox" }
  }, {
    key = "q",
    label = "Safari",
    kind = "application",
    action = { type = "launchApp", name = "Safari" }
  }
  }
}
