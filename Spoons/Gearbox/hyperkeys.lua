--- Hold Hyper (Control + Option + Command + Shift) and press a letter.
-- Strings launch apps. An openMenu target opens an existing Gearbox menu.
-- Use an empty table to disable Quick Launch.
return {
    a = "Agenda",
    b = "Bike",
    c = "Calendar",
    e = "System Settings",
    f = {type = "openMenu", menu = "finder"},
    k = "KeePassXC",
    l = "Calculator",
    m = "Mail",
    n = "Notes",
    o = "OmniFocus",
    p = "Passwords",
    s = "Siri",
    t = "ForkLift",
    z = "Zed"
}
