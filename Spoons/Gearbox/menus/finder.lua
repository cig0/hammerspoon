--- Finder folders submenu: Desktop, Documents, Downloads, Home, Pictures, tmp.
local home = os.getenv("HOME") or ""

return {
    id = "finder",
    title = "Finder Folders",
    emoji = "📁",
    parent = "leader",

    entry = {key = "f", label = "Finder Folders"},

    items = {
        {
            key = "a",
            label = "Applications",
            kind = "action",
            action = {
              type = "openPath",
              path = "/Applications"
            }
        }, {
            key = "e",
            label = "Desktop",
            kind = "action",
            action = {
              type = "openPath",
              path = home .. "/Desktop"}
        }, {
            key = "o",
            label = "Documents",
            kind = "action",
            action = {type = "openPath", path = home .. "/Documents"}
        }, {
            key = "d",
            label = "Downloads",
            kind = "action",
            action = {type = "openPath", path = home .. "/Downloads"}
        }, {
            key = "f",
            label = "Home",
            kind = "action",
            action = {type = "openPath", path = home}
        }, {
            key = "i",
            label = "iCloud",
            kind = "action",
            action = {
                type = "openPath",
                path = home .. "/Library/Mobile Documents/com~apple~CloudDocs"
            }
        }, {
            key = "p",
            label = "Pictures",
            kind = "action",
            action = {type = "openPath", path = home .. "/Pictures"}
        }, {
            key = "w",
            label = "Projects",
            kind = "action",
            action = {type = "openPath", path = home .. "/Projects"}
        }, {
            key = "t",
            label = "tmp",
            kind = "action",
            action = {type = "openPath", path = home .. "/tmp"}
        }, {
            key = "s",
            label = "Sync",
            kind = "action",
            action = {type = "openPath", path = home .. "/Sync"}
        }
    }
}
