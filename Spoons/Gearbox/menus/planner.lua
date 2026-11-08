--- Planner submenu: Calendar, Mail, Reminders.
return {
  id = "planner",
  title = "Planner",
  emoji = "📅",
  parent = "leader",

  entry = { key = "P", label = "Planner" },

  items = {
    {
      key = "c",
      label = "Calendar",
      kind = "application",
      action = { type = "launchApp", name = "Calendar" }
    }, {
    key = "m",
    label = "Mail",
    kind = "application",
    action = { type = "launchApp", name = "Mail" }
  }, {
    key = "n",
    label = "Notes",
    kind = "application",
    action = { type = "launchApp", name = "Notes" }
  }, {
    key = "r",
    label = "Reminders",
    kind = "application",
    action = { type = "launchApp", name = "Reminders" }
  }, {
    key = "t",
    label = "Things",
    kind = "application",
    action = { type = "launchApp", name = "Things" }
  }, {
    key = "o",
    label = "OmniFocus",
    kind = "application",
    action = { type = "launchApp", name = "OmniFocus" }
  }, {
    key = "s",
    label = "Structured",
    kind = "application",
    action = { type = "launchApp", name = "Structured" }
  }
  }
}
