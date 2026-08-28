--- Gearbox root menu: applications and the Scratchpad.
return {
    id = "leader",
    title = "Gearbox",
    emoji = "⚙️",
    showFooterDivider = true,

    items = {
        {
            key = "C",
            label = "Calculator",
            kind = "application",
            action = {type = "launchApp", name = "Calculator"}
        }, {
            key = "L",
            label = "ForkLift",
            kind = "application",
            action = {type = "launchApp", name = "ForkLift"}
        }, {
            key = "K",
            label = "KeePassXC",
            kind = "application",
            action = {type = "launchApp", name = "KeePassXC"}
        }, {
            key = "N",
            label = "Notes",
            kind = "application",
            action = {type = "launchApp", name = "Notes"}
        }, {
            key = "O",
            label = "Obsidian",
            kind = "application",
            action = {type = "launchApp", name = "Obsidian"}
        }, {
            key = "P",
            label = "Passwords",
            kind = "application",
            action = {type = "launchApp", name = "Passwords"}
        }, {
            key = "s",
            label = "Scratchpad",
            kind = "action",
            requires = "scratchpad",
            action = {type = "openScratchpad"}
        }
    }
}
