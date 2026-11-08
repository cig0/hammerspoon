--- Communications submenu: Discord, WhatsApp.
return {
  id = "comms",
  title = "Communications",
  emoji = "📞",
  parent = "leader",

  entry = { key = "C", label = "Communications" },

  items = {
    {
      key = "d",
      label = "Discord",
      kind = "application",
      action = { type = "launchApp", name = "Discord" }
    }, {
    key = "s",
    label = "Swiftcord",
    kind = "application",
    action = { type = "launchApp", name = "Swiftcord" }
  }, {
    key = "w",
    label = "WhatsApp",
    kind = "application",
    action = { type = "launchApp", name = "WhatsApp Web" }
  }
  }
}
