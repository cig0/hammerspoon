--- Planner submenu: Calendar, Mail, Reminders.
return {
  id = "planner",
  title = "Planner",
  emoji = "📅",
  parent = "leader",

  entry = { key = "P", label = "Planner" },

  items = {
    {
      key = "r",
      label = "Reminders",
      kind = "application",
      action = { type = "launchApp", name = "Reminders" }
    }, {
    key = "s",
    label = "Structured",
    kind = "application",
    action = { type = "launchApp", name = "Structured" }
  }
  }
}
