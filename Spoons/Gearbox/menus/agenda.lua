--- Agenda submenu: Calendar, Mail, Reminders.
return {
    id = "agenda",
    title = "Agenda",
    emoji = "📅",
    parent = "leader",

    entry = {key = "n", label = "Agenda"},

    items = {
        {
            key = "C",
            label = "Calendar",
            kind = "application",
            action = {type = "launchApp", name = "Calendar"}
        }, {
            key = "M",
            label = "Mail",
            kind = "application",
            action = {type = "launchApp", name = "Mail"}
        }, {
            key = "R",
            label = "Reminders",
            kind = "application",
            action = {type = "launchApp", name = "Reminders"}
        }
    }
}
