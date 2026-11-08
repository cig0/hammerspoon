--- Communications submenu: Discord, WhatsApp.
return {
  id = "comms",
  title = "Communications",
  emoji = "📞",
  parent = "leader",

  entry = { key = "C", label = "Communications" },

  items = {
    {
      key = "s",
      label = "Swiftcord",
      kind = "application",
      action = { type = "launchApp", name = "Swiftcord", bundleID = "com.swiftcord.Swiftcord" }
    }, {
    key = "w",
    label = "WhatsApp",
    kind = "application",
    -- Safari web app: bundleID ephemeral
    action = { type = "launchApp", name = "WhatsApp Web" }
  }
  }
}
