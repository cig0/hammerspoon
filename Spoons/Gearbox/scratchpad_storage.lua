--- Scratchpad content persistence.
--
-- The current Scratchpad configuration selects local `hs.settings` storage or
-- one regular UTF-8 file. File writes replace the destination atomically and
-- never fall back to the other backend after an error.
local Storage = {}
Storage.__index = Storage

local settingsKey = "Gearbox.scratchpad.content"

local function expandHome(path)
    if path:sub(1, 2) ~= "~/" then return path end

    local home = assert(os.getenv("HOME"), "Gearbox: HOME is unavailable")
    return home .. path:sub(2)
end

local function directoryName(path)
    return path:match("^(.+)/[^/]+$") or "/"
end

function Storage.new(config)
    return setmetatable({config = config}, Storage)
end

--- Return whether the current configuration selects `hs.settings`.
---@return boolean
function Storage:isSettings()
    return self.config.scratchpad.storagePath == nil
end

function Storage:filePath()
    local path = self.config.scratchpad.storagePath
    return path and expandHome(path) or nil
end

--- Validate the regular-file boundary without creating its parent directory.
---@param path string
---@param allowMissing boolean
---@return boolean|nil, string|nil
function Storage:validateFile(path, allowMissing)
    local linkMode = hs.fs.symlinkAttributes(path, "mode")

    if linkMode == "link" then
        return nil, "symbolic links are not supported: " .. path
    end

    local mode, attributeError = hs.fs.attributes(path, "mode")

    if mode == "file" then return true end

    if mode ~= nil then return nil, "not a regular file: " .. path end

    if not allowMissing then
        return nil, attributeError or "file does not exist: " .. path
    end

    local parentMode, parentError = hs.fs.attributes(directoryName(path), "mode")

    if parentMode ~= "directory" then
        return nil, parentError or "parent directory does not exist: " ..
                   directoryName(path)
    end

    return true
end

--- Load content from the currently selected backend.
---@return string|nil, string|nil
function Storage:load()
    if self:isSettings() then
        local stored = hs.settings.get(settingsKey)
        return type(stored) == "string" and stored or ""
    end

    local path = self:filePath()
    local mode = hs.fs.attributes(path, "mode")

    if mode == nil then
        local valid, validationError = self:validateFile(path, true)
        return valid and "" or nil, validationError
    end

    local valid, validationError = self:validateFile(path, false)

    if not valid then return nil, validationError end

    local file, openError = io.open(path, "rb")

    if not file then return nil, openError end

    local content = file:read("*a")
    local closed, closeError = file:close()

    if not content then return nil, "cannot read " .. path end

    if not closed then return nil, closeError end

    return content
end

-- Allocate beside the destination so rename stays on one filesystem. Only
-- the shell creating the empty file needs the restrictive umask.
local function stageFile(path)
    local parent = directoryName(path)
    local quotedParent = "'" .. parent:gsub("'", "'\\''") .. "'"
    local command = "cd " .. quotedParent .. [[ && umask 077 &&
        stage=$(/usr/bin/mktemp -d .gearbox.XXXXXXXX) &&
        if ( : > "$stage/content" ); then
            printf '%s\n' "$stage"
        else
            rmdir "$stage"
            exit 1
        fi]]
    local pipe, openError = io.popen(command, "r")
    if not pipe then return nil, openError end

    local name = pipe:read("*l")
    local ok = pipe:close()
    if not ok or not name then return nil, "cannot stage save in " .. parent end

    return parent .. "/" .. name
end

--- Save content to the selected backend.
---@param content string
---@return boolean|nil, string|nil
function Storage:save(content)
    if self:isSettings() then
        hs.settings.set(settingsKey, content)
        return true
    end

    local path = self:filePath()
    local valid, validationError = self:validateFile(path, true)

    if not valid then return nil, validationError end

    local stage, stageError = stageFile(path)
    if not stage then return nil, stageError end

    local temporaryPath = stage .. "/content"
    local file, openError = io.open(temporaryPath, "wb")

    if not file then
        os.remove(temporaryPath)
        os.remove(stage)
        return nil, openError
    end

    local written, writeError = file:write(content)

    if written then written, writeError = file:flush() end

    local closed, closeError = file:close()

    local saved, saveError = written and closed, writeError or closeError
    if saved then saved, saveError = os.rename(temporaryPath, path) end
    if not saved then os.remove(temporaryPath) end
    local cleaned, cleanupError = os.remove(stage)
    if not saved then return nil, saveError or "cannot write " .. path end
    return cleaned, cleanupError
end

return Storage
