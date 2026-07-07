return {
  id = "ai",
  title = "AI",
  emoji = "🤖",
  parent = "leader",

  entry = {
    key = "i",
    label = "AI",
  },

  items = {
    {
      key = "c",
      label = "ChatGPT",
      kind = "application",
      action = {
        type = "launchApp",
        name = "ChatGPT",
      },
    },
    {
      key = "g",
      label = "Gemini",
      kind = "application",
      action = {
        type = "launchApp",
        name = "Gemini",
      },
    },
  },
}
