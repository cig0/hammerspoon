--- Gearbox root menu: Calculator, ForkLift, KeePassXC, Passwords.
return {
  id = "leader",
  title = "Gearbox",
  emoji = "⚙️",
  highlightGroups = true,

  items = {
    {
      key = "c",
      label = "Calculator",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Calculator",
      },
    },
    {
      key = "l",
      label = "ForkLift",
      kind = "application",
      action = {
        type = "launchApp",
        name = "ForkLift",
      },
    },
    {
      key = "k",
      label = "KeePassXC",
      kind = "application",
      action = {
        type = "launchApp",
        name = "KeePassXC",
      },
    },
    {
      key = "o",
      label = "Obsidian",
      kind = "application",
      action = {
        type = "launchapp",
        name = "Obsidian",
      },
    },
    {
      key = "s",
      label = "Passwords",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Passwords",
      },
    },
  },
}
