return {
  id = "agenda",
  title = "Agenda",
  emoji = "📅",
  parent = "leader",

  entry = {
    key = "n",
    label = "Agenda",
  },

  items = {
    {
      key = "c",
      label = "Calendar",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Calendar",
      },
    },
    {
      key = "m",
      label = "Mail",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Mail",
      },
    },
    {
      key = "r",
      label = "Reminders",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Reminders",
      },
    },
  },
}
