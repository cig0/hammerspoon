--- Button value validation and visual-state selection.
local Validation = require((...):match("^(.*)%.button$") .. ".validation")
local Button = {}

function Button.validate(definition, name)
    name = name or "button"
    Validation.type(definition, "table", name)
    Validation.exactKeys(definition, {id = true, label = true, hotkey = true, default = true, enabled = true}, name)
    Validation.type(definition.id, "string", name .. ".id")
    Validation.type(definition.label, "string", name .. ".label")
    Validation.type(definition.hotkey, "string", name .. ".hotkey")
    Validation.type(definition.default, "boolean", name .. ".default")
    Validation.type(definition.enabled, "boolean", name .. ".enabled")
    if definition.id == "" or definition.label == "" or definition.hotkey == "" then Validation.fail(name .. " id, label, and hotkey cannot be empty", 2) end
    if not definition.hotkey:match("^[A-Za-z0-9]$") then
        Validation.fail(name .. ".hotkey must be one ASCII letter or digit", 2)
    end
    if not definition.label:lower():find(definition.hotkey:lower(), 1, true) then
        Validation.fail(name .. ".hotkey must appear in its label", 2)
    end
end

function Button.state(id, group)
    local definition = group.byId[id]
    if not definition.enabled then return "disabled" end
    if group.armedId == id then return "pressed" end
    if group.focusedId == id then return "focused" end
    if group.hoveredId == id then return "hovered" end
    return "normal"
end

return Button
