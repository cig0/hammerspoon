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
      action = { type = "launchApp", name = "Brave Origin", bundleID = "com.brave.Browser" }
    }, {
    key = "f",
    label = "Firefox",
    kind = "application",
    action = { type = "launchApp", name = "Firefox", bundleID = "org.mozilla.firefox" }
  }, {
    key = "t",
    label = "TiledBrowser",
    kind = "application",
    action = { type = "launchApp", name = "TiledBrowser" }
  }
  }
}
