--- AI submenu.
return {
  id = "ai",
  title = "AI",
  emoji = "🤖",
  parent = "leader",

  entry = { key = "I", label = "AI" },

  items = {
    {
      key = "o",
      label = "Osaurus",
      kind = "application",
      action = { type = "launchApp", name = "Osaurus" }
    }
  }
}
