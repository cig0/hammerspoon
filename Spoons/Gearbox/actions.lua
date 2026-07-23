local M = {}

local caffeinateModes = {
  display = true,
  idle = true,
  normal = true,
}

local function expect(value, expectedType, message)
  if type(value) ~= expectedType then
    error(message, 3)
  end
end

function M.validate(action, location)
  location = location or "menu item"

  expect(action, "table", location .. " must define an action table")
  expect(action.type, "string", location .. " action is missing its type")

  if action.type == "launchApp" then
    expect(action.name, "string", location .. " launchApp action requires name")
  elseif action.type == "openPath" then
    expect(action.path, "string", location .. " openPath action requires path")
  elseif action.type == "openMenu" then
    expect(action.menu, "string", location .. " openMenu action requires menu")
  elseif action.type == "setCaffeinateMode" then
    if not caffeinateModes[action.mode] then
      error(location .. " has invalid caffeinate mode: " .. tostring(action.mode), 2)
    end
  elseif action.type == "setTheme" then
    expect(action.theme, "string", location .. " setTheme action requires theme")

    if action.theme == "" then
      error(location .. " setTheme action requires a non-empty theme", 2)
    end
  elseif action.type == "openScratchpad" then
    return
  elseif action.type == "custom" then
    expect(action.run, "function", location .. " custom action requires run")
  elseif action.type ~= "exit"
      and action.type ~= "reload"
      and action.type ~= "sleep" then
    error(location .. " has unsupported action type: " .. action.type, 2)
  end
end

function M.isCheckable(action)
  return action
      and (
        action.type == "setCaffeinateMode"
        or action.type == "setTheme"
      )
end

function M.currentCaffeinateMode()
  -- Prefer the stronger display assertion if another tool enabled both.
  if hs.caffeinate.get("displayIdle") == true then
    return "display"
  end

  if hs.caffeinate.get("systemIdle") == true then
    return "idle"
  end

  return "normal"
end

local function setCaffeinateMode(mode)
  if mode == "display" then
    hs.caffeinate.set("systemIdle", false)
    hs.caffeinate.set("displayIdle", true)
  elseif mode == "idle" then
    hs.caffeinate.set("displayIdle", false)
    hs.caffeinate.set("systemIdle", true)
  else
    hs.caffeinate.set("displayIdle", false)
    hs.caffeinate.set("systemIdle", false)
  end
end

local function expandHome(path)
  local home = os.getenv("HOME")

  if not home then
    return path
  end

  if path == "~" then
    return home
  end

  if path:sub(1, 2) == "~/" then
    return home .. path:sub(2)
  end

  return path
end

function M.execute(action, context)
  if action.type == "launchApp" then
    hs.application.launchOrFocus(action.name)
    return { close = true }
  end

  if action.type == "openPath" then
    hs.open(expandHome(action.path))
    return { close = true }
  end

  if action.type == "openMenu" then
    context.openMenu(action.menu)
    return { handled = true }
  end

  if action.type == "exit" then
    context.exit()
    return { handled = true }
  end

  if action.type == "setCaffeinateMode" then
    setCaffeinateMode(action.mode)
    return { refresh = true }
  end

  if action.type == "setTheme" then
    context.setTheme(action.theme)
    return { refresh = true }
  end

  if action.type == "openScratchpad" then
    context.openScratchpad()
    return { handled = true }
  end

  if action.type == "sleep" then
    hs.caffeinate.systemSleep()
    return { close = true }
  end

  if action.type == "reload" then
    hs.reload()
    return { handled = true }
  end

  if action.type == "custom" then
    local result = action.run(context)

    if result == nil then
      return {}
    end

    assert(
      type(result) == "table",
      "Gearbox: custom actions must return a table or nil"
    )

    return result
  end

  error("Gearbox: unsupported action type reached runtime: " .. tostring(action.type))
end

return M
