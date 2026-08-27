--- AI submenu: ChatGPT, Gemini.
return {
    id = "ai",
    title = "AI",
    emoji = "🤖",
    parent = "leader",

    entry = {key = "i", label = "AI"},

    items = {
        {
            key = "C",
            label = "ChatGPT",
            kind = "application",
            action = {type = "launchApp", name = "ChatGPT"}
        }, {
            key = "G",
            label = "Gemini",
            kind = "application",
            action = {type = "launchApp", name = "Gemini"}
        }
    }
}
