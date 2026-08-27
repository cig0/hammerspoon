--- Web browsers submenu: Brave Origin, ChatGPT Atlas, Comet, Firefox, Safari.
return {
    id = "browsers",
    title = "Web Browsers",
    emoji = "🌐",
    parent = "leader",

    entry = {key = "w", label = "Web Browsers"},

    items = {
        {
            key = "O",
            label = "Brave Origin",
            kind = "application",
            action = {type = "launchApp", name = "Brave Origin"}
        }, {
            key = "A",
            label = "ChatGPT Atlas",
            kind = "application",
            action = {type = "launchApp", name = "ChatGPT Atlas"}
        }, {
            key = "C",
            label = "Comet Browser",
            kind = "application",
            action = {type = "launchApp", name = "Comet"}
        }, {
            key = "F",
            label = "Firefox",
            kind = "application",
            action = {type = "launchApp", name = "Firefox"}
        }, {
            key = "S",
            label = "Safari",
            kind = "application",
            action = {type = "launchApp", name = "Safari"}
        }
    }
}
