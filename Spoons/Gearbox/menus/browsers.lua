--- Web browsers submenu: Brave Origin, ChatGPT Atlas, Comet Browser, Safari.
return {
  id = "browsers",
  title = "Web Browsers",
  emoji = "🌐",
  parent = "leader",

  entry = {
    key = "w",
    label = "Web Browsers",
  },

  items = {
    {
      key = "o",
      label = "Brave Origin",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Brave Origin",
      },
    },
    {
      key = "a",
      label = "ChatGPT Atlas",
      kind = "application",
      action = {
        type = "launchApp",
        name = "ChatGPT Atlas",
      },
    },
    {
      key = "c",
      label = "Comet Browser",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Comet",
      },
    },
    {
      key = "s",
      label = "Safari",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Safari",
      },
    },
  },
}
