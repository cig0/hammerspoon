local root = assert(arg[1], "repository root argument is required")
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local files = {
    "README.md", "button.lua", "button_group.lua", "canvas_renderer.lua",
    "dialog.lua", "frame.lua", "init.lua", "package.json", "theme.lua",
    "validation.lua", "themes/borland.lua", "themes/danger.lua",
    "themes/monochrome.lua"
}
local listedFiles = {}
for _, relative in ipairs(files) do listedFiles[relative] = true end

local function read(path)
    local file = assert(io.open(path, "rb"))
    local value = file:read("*a")
    file:close()
    return value
end

local function write(path, value)
    local file = assert(io.open(path, "wb"))
    file:write(value)
    file:close()
end

local function run(command)
    local first, _, code = os.execute(command)
    return first == true or first == 0 or code == 0
end

local temporary = assert(os.tmpname())
assert(run(("rm -f %q"):format(temporary)))
assert(run(("mkdir -p %q/Spoons/Gearbox/lib/RetroUI/themes"):format(temporary)))
assert(run(("mkdir -p %q/Spoons/Gearbox"):format(temporary)))

local canonicalDirectory = root .. "/lib/RetroUI"
local bundledDirectory = root .. "/Spoons/Gearbox/lib/RetroUI"
local discovered = assert(io.popen(("/usr/bin/find %q -type f -print"):format(
                                       canonicalDirectory)))
for path in discovered:lines() do
    local relative = path:sub(#canonicalDirectory + 2)
    assert(listedFiles[relative],
           "package test file list is missing: " .. relative)
end
assert(discovered:close())

discovered = assert(io.popen(("/usr/bin/find %q -type f -print"):format(
                                bundledDirectory)))
for path in discovered:lines() do
    local relative = path:sub(#bundledDirectory + 2)
    assert(listedFiles[relative],
           "shipped bundle file list is missing: " .. relative)
end
assert(discovered:close())

for _, relative in ipairs(files) do
    local source = root .. "/lib/RetroUI/" .. relative
    local bundledSource = root .. "/Spoons/Gearbox/lib/RetroUI/" .. relative
    local destination = temporary .. "/Spoons/Gearbox/lib/RetroUI/" .. relative
    assert(read(bundledSource) == read(source),
           "shipped bundle differs: " .. relative)
    write(destination, read(bundledSource))
    assert(read(destination) == read(source), "assembled bundle differs: " .. relative)
end
write(temporary .. "/Spoons/Gearbox/dependencies.lua",
      read(root .. "/Spoons/Gearbox/dependencies.lua"))

local originalPath = package.path
package.path = temporary .. "/?.lua;" .. temporary .. "/?/init.lua;" .. originalPath
package.loaded["Spoons.Gearbox.dependencies"] = nil
package.loaded["Spoons.Gearbox.lib.RetroUI"] = nil
package.loaded["lib.RetroUI"] = nil
local bundled = require("Spoons.Gearbox.dependencies").retroUI()
assert(bundled.Frame and bundled.Dialog,
       "a present private bundle must load under the private namespace")
assert(package.loaded["Spoons.Gearbox.lib.RetroUI"] == bundled and
           package.loaded["lib.RetroUI"] == nil,
       "Gearbox must consume its shipped RetroUI namespace")

package.loaded["Spoons.Gearbox.dependencies"] = nil
package.loaded["Spoons.Gearbox.lib.RetroUI"] = nil
write(temporary .. "/Spoons/Gearbox/lib/RetroUI/init.lua", "error('broken private bundle')\n")
local broken = pcall(function()
    require("Spoons.Gearbox.dependencies").retroUI()
end)
assert(not broken, "a broken private bundle must not fall back silently")

assert(os.remove(temporary .. "/Spoons/Gearbox/lib/RetroUI/init.lua"))
local rawLoader = assert(loadfile(temporary .. "/Spoons/Gearbox/dependencies.lua"))()
package.path = originalPath
package.loaded["lib.RetroUI"] = nil
local canonical = rawLoader.retroUI()
assert(canonical.Frame and canonical.Dialog,
       "a full checkout must fall back to canonical RetroUI")

assert(run(("mkdir -p %q/lib/RetroUI"):format(temporary)))
write(temporary .. "/lib/RetroUI/init.lua", "error('broken canonical bundle')\n")
package.loaded["lib.RetroUI"] = nil
package.path = temporary .. "/?.lua;" .. temporary .. "/?/init.lua;"
local canonicalBroken, canonicalError = pcall(rawLoader.retroUI)
assert(not canonicalBroken and
           tostring(canonicalError):match("broken canonical bundle"),
       "an existing canonical module must propagate its own error")
assert(os.remove(temporary .. "/lib/RetroUI/init.lua"))
package.loaded["lib.RetroUI"] = nil
local missing, message = pcall(rawLoader.retroUI)
package.path = originalPath
assert(not missing and tostring(message):match("RetroUI is missing"),
       "a raw Gearbox copy must report an actionable missing-library error")

assert(run(("rm -rf %q"):format(temporary)))
print("RetroUI package tests passed")
