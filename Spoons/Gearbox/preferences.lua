--- Runtime preferences and generated configuration menus.
--
-- Input: validated `config.lua`, an optional versioned JSON profile, and local
-- `hs.settings` overrides. Output: the effective mutable configuration shared
-- by the HUD and Scratchpad plus passive menu definitions for editing it.
local Preferences = {}
Preferences.__index = Preferences

local profilePath = "~/.config/hammerspoon-gearbox/preferences.json"
local settingsKey = "Gearbox.preferences.local.v1"
local schemaVersion = 1

local positions = {top = true, center = true, bottom = true}
local configurableOperations = {
    chooseStorageFolder = true,
    reloadProfile = true,
    resetLocal = true,
    saveProfile = true,
    setFilename = true,
    setHeight = true,
    setPosition = true,
    setWidth = true,
    togglePersistence = true,
    useHammerspoonStorage = true
}

local checkableOperations = {
    chooseStorageFolder = true,
    setPosition = true,
    togglePersistence = true,
    useHammerspoonStorage = true
}

local function fail(message) error("Gearbox preferences: " .. message, 3) end

local function copy(value)
    if type(value) ~= "table" then return value end

    local result = {}

    for key, item in pairs(value) do result[key] = copy(item) end

    return result
end

local function rejectUnknown(value, allowed, name)
    for key in pairs(value) do
        if not allowed[key] then fail(name .. " has unknown field: " .. key) end
    end
end

local function expandHome(path)
    if path:sub(1, 2) ~= "~/" then return path end

    local home = assert(os.getenv("HOME"), "Gearbox: HOME is unavailable")
    return home .. path:sub(2)
end

local function collapseHome(path)
    local home = assert(os.getenv("HOME"), "Gearbox: HOME is unavailable")

    if path == home then return "~" end

    if path:sub(1, #home + 1) == home .. "/" then
        return "~" .. path:sub(#home + 1)
    end

    return path
end

local function directoryName(path)
    return path:match("^(.*)/[^/]+$") or "/"
end

local function baseName(path) return path:match("([^/]+)$") end

local function validStoragePath(path)
    return type(path) == "string" and path ~= "" and
               (path:sub(1, 1) == "/" or path:sub(1, 2) == "~/")
end

local function validateStorage(storage, name)
    if type(storage) ~= "table" then fail(name .. " must be an object") end

    rejectUnknown(storage, {backend = true, path = true}, name)

    if storage.backend == "settings" then
        if storage.path ~= nil then
            fail(name .. ".path is only valid for the file backend")
        end
    elseif storage.backend == "file" then
        if not validStoragePath(storage.path) then
            fail(name .. ".path must be absolute or begin with ~/")
        end
    else
        fail(name .. ".backend must be settings or file")
    end
end

local function validateRecord(record, name, complete)
    if type(record) ~= "table" then fail(name .. " must be an object") end

    rejectUnknown(record, {
        menu = true,
        schemaVersion = true,
        scratchpad = true
    }, name)

    if record.schemaVersion ~= schemaVersion then
        fail(name .. ".schemaVersion must be " .. schemaVersion)
    end

    if complete and type(record.menu) ~= "table" then
        fail(name .. ".menu is required")
    end

    if record.menu ~= nil then
        if type(record.menu) ~= "table" then fail(name .. ".menu must be an object") end

        rejectUnknown(record.menu, {position = true}, name .. ".menu")

        if complete and record.menu.position == nil then
            fail(name .. ".menu.position is required")
        end

        if record.menu.position ~= nil and not positions[record.menu.position] then
            fail(name .. ".menu.position must be top, center, or bottom")
        end
    end

    if complete and type(record.scratchpad) ~= "table" then
        fail(name .. ".scratchpad is required")
    end

    if record.scratchpad ~= nil then
        local scratchpad = record.scratchpad

        if type(scratchpad) ~= "table" then
            fail(name .. ".scratchpad must be an object")
        end

        rejectUnknown(scratchpad, {
            height = true,
            persistContent = true,
            storage = true,
            width = true
        }, name .. ".scratchpad")

        for _, field in ipairs({"persistContent", "storage", "width", "height"}) do
            if complete and scratchpad[field] == nil then
                fail(name .. ".scratchpad." .. field .. " is required")
            end
        end

        if scratchpad.persistContent ~= nil and
            type(scratchpad.persistContent) ~= "boolean" then
            fail(name .. ".scratchpad.persistContent must be a boolean")
        end

        if scratchpad.storage ~= nil then
            validateStorage(scratchpad.storage, name .. ".scratchpad.storage")
        end

        if scratchpad.width ~= nil and
            (type(scratchpad.width) ~= "number" or scratchpad.width < 360) then
            fail(name .. ".scratchpad.width must be at least 360")
        end

        if scratchpad.height ~= nil and
            (type(scratchpad.height) ~= "number" or scratchpad.height < 240) then
            fail(name .. ".scratchpad.height must be at least 240")
        end
    end
end

local function snapshot(config)
    local storage = {backend = "settings"}

    if config.scratchpad.storagePath ~= nil then
        storage = {backend = "file", path = config.scratchpad.storagePath}
    end

    return {
        schemaVersion = schemaVersion,
        menu = {position = config.menu.position},
        scratchpad = {
            persistContent = config.scratchpad.persistContent,
            storage = storage,
            width = config.scratchpad.width,
            height = config.scratchpad.height
        }
    }
end

local function applyRecord(config, record)
    if record.menu and record.menu.position ~= nil then
        config.menu.position = record.menu.position
    end

    local scratchpad = record.scratchpad

    if not scratchpad then return end

    if scratchpad.persistContent ~= nil then
        config.scratchpad.persistContent = scratchpad.persistContent
    end

    if scratchpad.storage ~= nil then
        config.scratchpad.storagePath = scratchpad.storage.backend == "file" and
                                            scratchpad.storage.path or nil
    end

    if scratchpad.width ~= nil then config.scratchpad.width = scratchpad.width end

    if scratchpad.height ~= nil then
        config.scratchpad.height = scratchpad.height
    end
end

local function ensureDirectory(path)
    local mode, attributeError = hs.fs.attributes(path, "mode")

    if mode ~= nil then
        if mode ~= "directory" then fail(path .. " is not a directory") end

        return
    end

    local parent = directoryName(path)

    if parent ~= path then ensureDirectory(parent) end

    local created, mkdirError = hs.fs.mkdir(path)

    if not created then
        fail(("cannot create %s: %s"):format(path, mkdirError or
                                                  attributeError or
                                                  "unknown error"))
    end
end

--- Return true when an action belongs to the generated configuration menus.
---@param action table
---@return boolean
function Preferences.isConfigurationAction(action)
    return action and action.type == "configure" and
               configurableOperations[action.operation] == true
end

--- Return true when a configuration action displays a checkmark.
---@param action table
---@return boolean
function Preferences.isCheckableAction(action)
    return Preferences.isConfigurationAction(action) and
               checkableOperations[action.operation] == true
end

--- Validate a passive configuration action descriptor.
---@param action table
---@param location string
function Preferences.validateAction(action, location)
    if type(action.operation) ~= "string" or
        not configurableOperations[action.operation] then
        fail(location .. " has invalid configure operation")
    end

    if action.operation == "setPosition" and
        not ({top = true, bottom = true})[action.value] then
        fail(location .. " configure position must be top or bottom")
    end
end

--- Load preferences and apply them to the shared runtime configuration.
---@param config table
---@return table
function Preferences.new(config)
    local self = setmetatable({}, Preferences)

    -- `require` caches config.lua. Own a copy so a stop/start cycle cannot turn
    -- values from the previous runtime into the next runtime's defaults.
    self.config = copy(config)
    self.defaults = snapshot(self.config)
    self.profile = self:readProfile()
    self.localOverrides = self:readLocalOverrides()

    self:apply()

    return self
end

--- Return the fixed, portable profile location shown in documentation and UI.
---@return string
function Preferences.profilePath() return profilePath end

function Preferences:readProfile()
    local path = expandHome(profilePath)
    local mode = hs.fs.attributes(path, "mode")

    if mode == nil then return nil end

    if mode ~= "file" then fail(profilePath .. " must be a regular file") end

    local record = hs.json.read(path)

    if record == nil then fail("cannot read valid JSON from " .. profilePath) end

    validateRecord(record, "profile", true)
    return record
end

function Preferences:readLocalOverrides()
    local record = hs.settings.get(settingsKey)

    if record == nil then return {schemaVersion = schemaVersion} end

    validateRecord(record, "local overrides", false)
    return copy(record)
end

function Preferences:apply()
    applyRecord(self.config, self.defaults)

    if self.profile then applyRecord(self.config, self.profile) end

    applyRecord(self.config, self.localOverrides)
end

function Preferences:persistLocalOverrides()
    hs.settings.set(settingsKey, self.localOverrides)
    self:apply()
end

function Preferences:setMenuPosition(position)
    self.localOverrides.menu = self.localOverrides.menu or {}
    self.localOverrides.menu.position = position
    self:persistLocalOverrides()
end

function Preferences:setScratchpadValue(name, value)
    self.localOverrides.scratchpad = self.localOverrides.scratchpad or {}
    self.localOverrides.scratchpad[name] = value
    self:persistLocalOverrides()
end

function Preferences:setStorage(storage)
    self.localOverrides.scratchpad = self.localOverrides.scratchpad or {}
    self.localOverrides.scratchpad.storage = storage
    self:persistLocalOverrides()
end

function Preferences:chooseStorageFolder()
    local currentPath = self.config.scratchpad.storagePath
    local defaultDirectory = currentPath and directoryName(expandHome(currentPath)) or
                                 os.getenv("HOME")
    local selected = hs.dialog.chooseFileOrFolder(
                         "Choose the Gearbox Scratchpad folder",
                         defaultDirectory, false, true, false)

    if type(selected) ~= "table" or type(selected[1]) ~= "string" then return end

    local filename = currentPath and baseName(currentPath) or "scratchpad.txt"
    local path = selected[1]:gsub("/$", "") .. "/" .. filename

    self:setStorage({backend = "file", path = collapseHome(path)})
end

function Preferences:setFilename()
    local currentPath = self.config.scratchpad.storagePath

    if currentPath == nil then
        hs.alert.show("Choose an external Scratchpad folder first", nil, nil, 3)
        return
    end

    local button, filename = hs.dialog.textPrompt(
                                 "Scratchpad filename",
                                 "Enter a filename without directory separators.",
                                 baseName(currentPath), "Save", "Cancel")

    if button ~= "Save" then return end

    if filename == "" or filename == "." or filename == ".." or
        filename:find("/", 1, true) then
        hs.alert.show("Scratchpad filename is invalid", nil, nil, 3)
        return
    end

    self:setStorage({
        backend = "file",
        path = directoryName(currentPath) .. "/" .. filename
    })
end

function Preferences:setDimension(name, minimum)
    local current = self.config.scratchpad[name]
    local button, text = hs.dialog.textPrompt(
                             "Scratchpad " .. name,
                             ("Enter an integer of at least %d points."):format(
                                 minimum), tostring(current), "Save", "Cancel")

    if button ~= "Save" then return end

    local value = tonumber(text)

    if value == nil or value < minimum or value % 1 ~= 0 then
        hs.alert.show("Scratchpad " .. name .. " is invalid", nil, nil, 3)
        return
    end

    self:setScratchpadValue(name, value)
end

function Preferences:saveProfile()
    local path = expandHome(profilePath)

    ensureDirectory(directoryName(path))

    local record = snapshot(self.config)

    if not hs.json.write(record, path, true, true) then
        fail("cannot write " .. profilePath)
    end

    self.profile = record
    self.localOverrides = {schemaVersion = schemaVersion}
    hs.settings.clear(settingsKey)
    self:apply()
    hs.alert.show("Gearbox profile saved", nil, nil, 3)
end

function Preferences:reloadProfile()
    self.profile = self:readProfile()
    self:apply()
    hs.alert.show(self.profile and "Gearbox profile reloaded" or
                      "Gearbox profile not found", nil, nil, 3)
end

function Preferences:resetLocalOverrides()
    self.localOverrides = {schemaVersion = schemaVersion}
    hs.settings.clear(settingsKey)
    self:apply()
    hs.alert.show("Gearbox local overrides cleared", nil, nil, 3)
end

--- Execute one validated configuration action without leaking UI failures.
---@param action table
function Preferences:execute(action)
    local ok, actionError = xpcall(function()
        local operation = action.operation

        if operation == "setPosition" then
            self:setMenuPosition(action.value)
        elseif operation == "togglePersistence" then
            self:setScratchpadValue("persistContent",
                                    not self.config.scratchpad.persistContent)
        elseif operation == "useHammerspoonStorage" then
            self:setStorage({backend = "settings"})
        elseif operation == "chooseStorageFolder" then
            self:chooseStorageFolder()
        elseif operation == "setFilename" then
            self:setFilename()
        elseif operation == "setWidth" then
            self:setDimension("width", 360)
        elseif operation == "setHeight" then
            self:setDimension("height", 240)
        elseif operation == "saveProfile" then
            self:saveProfile()
        elseif operation == "reloadProfile" then
            self:reloadProfile()
        elseif operation == "resetLocal" then
            self:resetLocalOverrides()
        end
    end, debug.traceback)

    if not ok then
        print(actionError)
        hs.alert.show("Gearbox configuration failed; see the console", nil, nil,
                      5)
    end
end

--- Return whether a configuration row represents the effective value.
---@param action table
---@return boolean
function Preferences:isSelected(action)
    if action.operation == "setPosition" then
        return self.config.menu.position == action.value
    elseif action.operation == "togglePersistence" then
        return self.config.scratchpad.persistContent
    elseif action.operation == "useHammerspoonStorage" then
        return self.config.scratchpad.storagePath == nil
    elseif action.operation == "chooseStorageFolder" then
        return self.config.scratchpad.storagePath ~= nil
    end

    return false
end

--- Refresh value-bearing row labels before the HUD renders a menu.
---@param menu table
function Preferences:refreshMenu(menu)
    for _, row in ipairs(menu.rows) do
        local action = row.action

        if Preferences.isConfigurationAction(action) then
            if action.operation == "setFilename" then
                row.label = "Filename: " ..
                                (baseName(self.config.scratchpad.storagePath or
                                              "scratchpad.txt"))
            elseif action.operation == "setWidth" then
                row.label = ("Width: %g pt"):format(self.config.scratchpad.width)
            elseif action.operation == "setHeight" then
                row.label = ("Height: %g pt"):format(
                                self.config.scratchpad.height)
            end
        end
    end
end

--- Build generated menu definitions consumed by `loader.lua`.
---@return table
function Preferences:menuDefinitions()
    return {
        {
            id = "configuration",
            title = "Gearbox Configuration",
            emoji = "⚙️",
            parent = "leader",
            entry = {
                key = "g",
                label = "Gearbox Configuration",
                section = "gearbox-configuration",
                sectionOrder = 300
            },
            items = {
                {
                    key = "h",
                    label = "Reload Hammerspoon",
                    kind = "action",
                    action = {type = "reload"}
                }, {divider = true},
                {
                    key = "p",
                    label = "Save Versioned Profile",
                    kind = "action",
                    action = {type = "configure", operation = "saveProfile"}
                }, {
                    key = "r",
                    label = "Reload Versioned Profile",
                    kind = "action",
                    action = {type = "configure", operation = "reloadProfile"}
                }, {
                    key = "x",
                    label = "Reset Local Overrides",
                    kind = "action",
                    action = {type = "configure", operation = "resetLocal"}
                }
            }
        }, {
            id = "menu-position",
            title = "Menu Position",
            parent = "configuration",
            entry = {key = "m", label = "Menu Position"},
            items = {
                {
                    key = "t",
                    label = "Top",
                    kind = "action",
                    action = {
                        type = "configure",
                        operation = "setPosition",
                        value = "top"
                    }
                }, {
                    key = "b",
                    label = "Bottom",
                    kind = "action",
                    action = {
                        type = "configure",
                        operation = "setPosition",
                        value = "bottom"
                    }
                }
            }
        }, {
            id = "scratchpad-settings",
            title = "Scratchpad",
            parent = "configuration",
            entry = {key = "s", label = "Scratchpad"},
            items = {
                {
                    key = "p",
                    label = "Persist Content",
                    kind = "action",
                    action = {
                        type = "configure",
                        operation = "togglePersistence"
                    }
                }, {
                    key = "h",
                    label = "Hammerspoon Settings",
                    kind = "action",
                    action = {
                        type = "configure",
                        operation = "useHammerspoonStorage"
                    }
                }, {
                    key = "f",
                    label = "External File…",
                    kind = "action",
                    action = {
                        type = "configure",
                        operation = "chooseStorageFolder"
                    }
                }, {
                    key = "n",
                    label = "Filename: scratchpad.txt",
                    kind = "action",
                    action = {type = "configure", operation = "setFilename"}
                }, {divider = true}, {
                    key = "w",
                    label = "Width",
                    kind = "action",
                    action = {type = "configure", operation = "setWidth"}
                }, {
                    key = "e",
                    label = "Height",
                    kind = "action",
                    action = {type = "configure", operation = "setHeight"}
                }
            }
        }
    }
end

return Preferences
