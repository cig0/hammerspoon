--- Photo & Video submenu: Affinity, Photos, PowerPhotos.
return {
  id = "photovideo",
  title = "Photo & Video",
  emoji = "📸",
  parent = "leader",

  entry = { key = "H", label = "Photo & Video" },

  items = {
    {
      key = "a",
      label = "Affinity",
      kind = "application",
      action = { type = "launchApp", name = "Affinity" }
    }, {
    key = "x",
    label = "NX Studio",
    kind = "application",
    action = { type = "launchApp", name = "NX Studio" }
  }, {
    key = "p",
    label = "Photos",
    kind = "application",
    action = { type = "launchApp", name = "Photos" }
  }
  }
}
