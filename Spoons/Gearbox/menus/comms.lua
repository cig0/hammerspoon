--- Communications submenu: Discord, WhatsApp.
return {
    id = "comms",
    title = "Communications",
    emoji = "📞",
    parent = "applications",

    entry = {key = "c", label = "Communications"},

    items = {
        {
            key = "D",
            label = "Discord",
            kind = "application",
            action = {type = "launchApp", name = "Discord"}
        }, {
            key = "W",
            label = "WhatsApp",
            kind = "application",
            action = {type = "launchApp", name = "WhatsApp"}
        }
    }
}
