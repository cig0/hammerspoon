local Loader = {}

local validKinds = {
  action = true,
  application = true,
}

local function fail(message)
  error("Gearbox: " .. message, 3)
end

local function copyTable(value)
  if type(value) ~= "table" then
    return value
  end

  local result = {}

  for key, item in pairs(value) do
    result[key] = copyTable(item)
  end

  return result
end

local function appendDivider(rows)
  if #rows > 0 and not rows[#rows].divider then
    table.insert(rows, { divider = true })
  end
end

local function validHotkeyKey(key)
  if key:match("^#%d+$") then
    return true
  end

  return hs.keycodes.map[key:lower()] ~= nil
end

local function keyIdentity(key)
  if key:match("^#%d+$") then
    return "#" .. tonumber(key:sub(2))
  end

  return key:lower()
end

local function menuFiles(directory)
  local files = {}

  for file in hs.fs.dir(directory) do
    local firstCharacter = file:sub(1, 1)

    if file:match("%.lua$")
        and firstCharacter ~= "."
        and firstCharacter ~= "_" then
      table.insert(files, file)
    end
  end

  table.sort(files)
  return files
end

local function addDefinition(definitions, definition, source)
  if type(definition) ~= "table" then
    fail(source .. " must return one menu definition")
  end

  if type(definition.id) ~= "string"
      or not definition.id:match("^[%w_-]+$") then
    fail(source .. " has an invalid or missing id")
  end

  if definitions[definition.id] then
    fail("duplicate menu id: " .. definition.id)
  end

  definition = copyTable(definition)
  definition._source = source
  definitions[definition.id] = definition
end

local function loadDefinitions(directory, supplementalDefinitions)
  local definitions = {}
  local files = menuFiles(directory)

  if #files == 0 then
    fail("no menu modules found in " .. directory)
  end

  for _, file in ipairs(files) do
    local path = directory .. "/" .. file
    local chunk, loadError = loadfile(path)

    if not chunk then
      fail(("cannot load %s: %s"):format(path, loadError))
    end

    local ok, definition = pcall(chunk)

    if not ok then
      fail(("menu module %s failed: %s"):format(path, definition))
    end

    addDefinition(definitions, definition, file)
  end

  for index, definition in ipairs(supplementalDefinitions or {}) do
    addDefinition(
      definitions,
      definition,
      ("supplemental menu %d"):format(index)
    )
  end

  return definitions
end

local function validateDefinitions(definitions, config, actions, theme)
  local rootIds = {}
  local reservedKeys = {
    [keyIdentity(config.navigation.cancelKey)] = true,
  }

  if config.navigation.enabled then
    reservedKeys.up = true
    reservedKeys.down = true
    reservedKeys[keyIdentity(config.navigation.activateKey)] = true
  end

  for id, definition in pairs(definitions) do
    if type(definition.title) ~= "string" or definition.title == "" then
      fail(id .. " is missing its title")
    end

    if definition.emoji ~= nil and type(definition.emoji) ~= "string" then
      fail(id .. " emoji must be a string")
    end

    if definition.parent == nil then
      table.insert(rootIds, id)
    else
      if type(definition.parent) ~= "string"
          or not definitions[definition.parent] then
        fail(id .. " references missing parent: " .. tostring(definition.parent))
      end

      if type(definition.entry) ~= "table" then
        fail(id .. " must define entry metadata for its parent")
      end

      if type(definition.entry.key) ~= "string"
          or definition.entry.key == "" then
        fail(id .. " parent entry is missing its key")
      end

      if not validHotkeyKey(definition.entry.key) then
        fail(id .. " parent entry has invalid key: " .. definition.entry.key)
      end

      if reservedKeys[keyIdentity(definition.entry.key)] then
        fail(id .. " parent entry uses reserved key: " .. definition.entry.key)
      end

      if definition.entry.label ~= nil
          and type(definition.entry.label) ~= "string" then
        fail(id .. " parent entry label must be a string")
      end

      if definition.entry.section ~= nil
          and type(definition.entry.section) ~= "string" then
        fail(id .. " parent entry section must be a string")
      end

      if definition.entry.order ~= nil
          and type(definition.entry.order) ~= "number" then
        fail(id .. " parent entry order must be a number")
      end

      if definition.entry.sectionOrder ~= nil
          and type(definition.entry.sectionOrder) ~= "number" then
        fail(id .. " parent entry sectionOrder must be a number")
      end
    end

    if definition.items ~= nil and type(definition.items) ~= "table" then
      fail(id .. " items must be a table")
    end

    local seenKeys = {}

    for index, item in ipairs(definition.items or {}) do
      if not item.divider then
        local location = ("%s item %d"):format(id, index)

        if type(item.key) ~= "string" or item.key == "" then
          fail(location .. " is missing its key")
        end

        if not validHotkeyKey(item.key) then
          fail(location .. " has invalid key: " .. item.key)
        end

        local identity = keyIdentity(item.key)

        if reservedKeys[identity] then
          fail(location .. " uses reserved key: " .. item.key)
        end

        if seenKeys[identity] then
          fail(id .. " has duplicate item key: " .. item.key)
        end

        if type(item.label) ~= "string" or item.label == "" then
          fail(location .. " is missing its label")
        end

        if not validKinds[item.kind] then
          fail(location .. " has invalid kind: " .. tostring(item.kind))
        end

        actions.validate(item.action, location)

        if item.action.type == "openMenu"
            and not definitions[item.action.menu] then
          fail(
            location
              .. " references missing menu: "
              .. item.action.menu
          )
        end

        if item.action.type == "setTheme"
            and (
              not theme
              or not theme:isValidSelection(item.action.theme)
            ) then
          fail(
            location
              .. " references missing theme: "
              .. item.action.theme
          )
        end

        seenKeys[identity] = true
      end
    end
  end

  if #rootIds ~= 1 then
    fail("expected exactly one root menu, found " .. #rootIds)
  end

  for id in pairs(definitions) do
    local visited = {}
    local current = id

    while definitions[current].parent do
      if visited[current] then
        fail("parent cycle detected at menu: " .. current)
      end

      visited[current] = true
      current = definitions[current].parent
    end
  end

  return rootIds[1]
end

local function sortedSections(sections)
  local result = {}

  for _, section in pairs(sections) do
    table.sort(section.children, function(left, right)
      local leftOrder = left.entry.order or math.huge
      local rightOrder = right.entry.order or math.huge

      if leftOrder ~= rightOrder then
        return leftOrder < rightOrder
      end

      local leftLabel = left.entry.label or left.title
      local rightLabel = right.entry.label or right.title

      if leftLabel ~= rightLabel then
        return leftLabel:lower() < rightLabel:lower()
      end

      return left.id < right.id
    end)

    table.insert(result, section)
  end

  table.sort(result, function(left, right)
    if left.order ~= right.order then
      return left.order < right.order
    end

    return left.id < right.id
  end)

  return result
end

local function assembleMenus(definitions, rootId, config, actions)
  local menus = {}
  local sectionsByParent = {}

  for id, definition in pairs(definitions) do
    menus[id] = {
      id = id,
      title = definition.title,
      emoji = definition.emoji or "",
      parentId = definition.parent,
      highlightGroups = definition.highlightGroups == true,
      rows = {},
    }

    if definition.parent then
      local parentSections = sectionsByParent[definition.parent] or {}
      local sectionId = definition.entry.section or "groups"
      local sectionOrder = definition.entry.sectionOrder or 100
      local section = parentSections[sectionId]

      if section and section.order ~= sectionOrder then
        fail(
          ("section %s in %s has conflicting sectionOrder values")
            :format(sectionId, definition.parent)
        )
      end

      if not section then
        section = {
          id = sectionId,
          order = sectionOrder,
          children = {},
        }
        parentSections[sectionId] = section
      end

      table.insert(section.children, definition)
      sectionsByParent[definition.parent] = parentSections
    end
  end

  for id, definition in pairs(definitions) do
    local menu = menus[id]
    local seenKeys = {}

    for _, item in ipairs(definition.items or {}) do
      local row = copyTable(item)

      if row.divider then
        appendDivider(menu.rows)
      else
        table.insert(menu.rows, row)
        seenKeys[keyIdentity(row.key)] = true
        row.checkable = actions.isCheckable(row.action)
        menu.hasChecks = menu.hasChecks or row.checkable
      end
    end

    for _, section in ipairs(sortedSections(sectionsByParent[id] or {})) do
      appendDivider(menu.rows)

      for _, child in ipairs(section.children) do
        local key = child.entry.key
        local identity = keyIdentity(key)

        if seenKeys[identity] then
          fail(("%s has duplicate item or child key: %s"):format(id, key))
        end

        table.insert(menu.rows, {
          key = key,
          label = child.entry.label or child.title,
          kind = "group",
          action = {
            type = "openMenu",
            menu = child.id,
          },
        })

        seenKeys[identity] = true
      end
    end

    appendDivider(menu.rows)

    local footerAction
    local footerLabel

    if id == rootId then
      footerAction = { type = "exit" }
      footerLabel = "Exit Gearbox (also: "
          .. table.concat(config.hotkey.modifiers, "+")
          .. "+"
          .. config.hotkey.key
          .. ")"
    else
      footerAction = {
        type = "openMenu",
        menu = definition.parent,
      }
      footerLabel = "Back to " .. definitions[definition.parent].title
    end

    table.insert(menu.rows, {
      key = config.navigation.cancelKey,
      label = footerLabel,
      kind = "footer",
      action = footerAction,
    })
  end

  for _, menu in pairs(menus) do
    menu.modal = hs.hotkey.modal.new()
  end

  return menus
end

function Loader.load(
  rootDirectory,
  config,
  actions,
  supplementalDefinitions,
  theme
)
  local definitions = loadDefinitions(
    rootDirectory .. "/menus",
    supplementalDefinitions
  )
  local rootId = validateDefinitions(definitions, config, actions, theme)
  local menus = assembleMenus(definitions, rootId, config, actions)

  return menus, rootId
end

return Loader
