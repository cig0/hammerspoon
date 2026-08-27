--- Developer tools submenu: Codex, Sublime Merge, VirtualBuddy, Zed.
return {
    id = "developer",
    title = "Developer Tools",
    emoji = "🛠️",
    parent = "leader",

    entry = {key = "d", label = "Developer Tools"},

    items = {
        {
            key = "C",
            label = "Codex",
            kind = "application",
            action = {type = "launchApp", name = "Codex"}
        }, {
            key = "S",
            label = "Sublime Merge",
            kind = "application",
            action = {type = "launchApp", name = "Sublime Merge"}
        }, {
            key = "V",
            label = "VirtualBuddy",
            kind = "application",
            action = {type = "launchApp", name = "VirtualBuddy"}
        }, {
            key = "Z",
            label = "Zed",
            kind = "application",
            action = {type = "launchApp", name = "Zed"}
        }
    }
}
