--- Resolve Gearbox's bundled first-party libraries.
local Dependencies = {}

local function sourceDirectory()
    local source = debug.getinfo(1, "S").source
    assert(source:sub(1, 1) == "@",
           "Gearbox: cannot determine dependency directory")
    local directory = source:sub(2):match("^(.*)/dependencies%.lua$")
    assert(directory, "Gearbox: cannot determine dependency directory")
    return directory
end

function Dependencies.retroUI()
    local privatePath = sourceDirectory() .. "/lib/RetroUI/init.lua"
    local private = io.open(privatePath, "r")
    if private then
        private:close()
        return require("Spoons.Gearbox.lib.RetroUI")
    end
    if package.loaded["lib.RetroUI"] ~= nil or
        package.preload["lib.RetroUI"] ~= nil or
        package.searchpath("lib.RetroUI", package.path) then
        return require("lib.RetroUI")
    end
    error("Gearbox: RetroUI is missing; install the packaged Gearbox Spoon", 2)
end

return Dependencies
