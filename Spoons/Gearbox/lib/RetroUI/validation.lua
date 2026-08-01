--- Pure RetroUI value validation helpers.
local Validation = {}

function Validation.fail(message, level) error("RetroUI: " .. message, (level or 1) + 1) end

function Validation.type(value, expected, name)
    if type(value) ~= expected then
        Validation.fail(name .. " must be a " .. expected, 2)
    end
end

function Validation.enum(value, allowed, name)
    if not allowed[value] then Validation.fail("invalid " .. name .. ": " .. tostring(value), 2) end
end

function Validation.nonNegativeInteger(value, name)
    Validation.type(value, "number", name)
    if value ~= value or value == math.huge or value == -math.huge or value < 0 or
        value % 1 ~= 0 then
        Validation.fail(name .. " must be a non-negative integer", 2)
    end
end

function Validation.nonNegativeNumber(value, name)
    Validation.type(value, "number", name)
    if value ~= value or value == math.huge or value == -math.huge or value < 0 then
        Validation.fail(name .. " must be a finite non-negative number", 2)
    end
end

function Validation.positiveNumber(value, name)
    Validation.type(value, "number", name)
    if value ~= value or value == math.huge or value == -math.huge or value <= 0 then
        Validation.fail(name .. " must be a finite positive number", 2)
    end
end

function Validation.array(value, name)
    Validation.type(value, "table", name)
    local count, maximum = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            Validation.fail(name .. " must be an array", 2)
        end
        count, maximum = count + 1, math.max(maximum, key)
    end
    if count ~= maximum then Validation.fail(name .. " must not contain holes", 2) end
    return count
end

function Validation.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Validation.copy(item) end
    return result
end

function Validation.color(value, name)
    Validation.type(value, "table", name)
    local grayscale = value.white ~= nil
    local rgb = value.red ~= nil or value.green ~= nil or value.blue ~= nil
    if grayscale == rgb then Validation.fail(name .. " must define white or red, green, and blue", 2) end
    Validation.exactKeys(value,
                         grayscale and {white = true, alpha = true} or
                             {red = true, green = true, blue = true, alpha = true},
                         name)
    local fields = grayscale and {"white"} or {"red", "green", "blue"}
    for _, field in ipairs(fields) do
        Validation.type(value[field], "number", name .. "." .. field)
        if value[field] ~= value[field] or value[field] == math.huge or
            value[field] == -math.huge or value[field] < 0 or value[field] > 1 then
            Validation.fail(name .. "." .. field .. " must be 0..1", 2)
        end
    end
    Validation.type(value.alpha, "number", name .. ".alpha")
    if value.alpha ~= value.alpha or value.alpha == math.huge or
        value.alpha == -math.huge or value.alpha < 0 or value.alpha > 1 then
        Validation.fail(name .. ".alpha must be 0..1", 2)
    end
end

function Validation.exactKeys(value, allowed, name)
    for key in pairs(value) do
        if not allowed[key] then Validation.fail(name .. " has unknown field: " .. key, 2) end
    end
end

return Validation
