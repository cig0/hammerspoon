--- Omni Software Suite submenu: OmniFocus, OmniOutliner.
return {
    id = "omni",
    title = "Omni Software Suite",
    emoji = "🟣",
    parent = "applications",

    entry = {key = "o", label = "Omni Software Suite"},

    items = {
        {
            key = "F",
            label = "OmniFocus",
            kind = "application",
            action = {type = "launchApp", name = "OmniFocus"}
        }, {
            key = "O",
            label = "OmniOutliner",
            kind = "application",
            action = {type = "launchApp", name = "OmniOutliner"}
        }
    }
}
