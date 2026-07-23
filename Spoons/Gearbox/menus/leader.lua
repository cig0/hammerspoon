--- Gearbox root menu: applications and the Scratchpad.
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
        type = "launchApp",
        name = "Obsidian",
      },
    },
    {
      key = "p",
      label = "Passwords",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Passwords",
      },
    },
    {
      key = "s",
      label = "Scratchpad",
      kind = "action",
      requires = "scratchpad",
      action = {
        type = "openScratchpad",
      },
    },
  },
}
