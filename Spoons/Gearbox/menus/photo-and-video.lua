--- Photo & Video submenu: Affinity, Photos, PowerPhotos.
return {
  id = "photovideo",
  title = "Photo & Video",
  emoji = "📸",
  parent = "applications",

  entry = {
    key = "p",
    label = "Photo & Video",
  },

  items = {
    {
      key = "a",
      label = "Affinity",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Affinity",
      },
    },
    {
      key = "p",
      label = "Photos",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Photos",
      },
    },
    {
      key = "o",
      label = "PowerPhotos",
      kind = "application",
      action = {
        type = "launchApp",
        name = "PowerPhotos",
      },
    },
  },
}
