--- Pure character-cell frame layout with semantic text roles.
local Validation = require((...):match("^(.*)%.frame$") .. ".validation")
local Frame = {}

local styles = {
    single = {topLeft = "┌", horizontal = "─", topRight = "┐", vertical = "│", bottomLeft = "└", bottomRight = "┘"},
    double = {topLeft = "╔", horizontal = "═", topRight = "╗", vertical = "║", bottomLeft = "╚", bottomRight = "╝"}
}
local alignments = {left = true, center = true, right = true}
local knownFields = {style = true, title = true, padding = true, rows = true}

-- v0.2 deliberately supports ASCII plus these single-cell frame glyphs. Keep
-- this isolated until a real wcwidth implementation becomes necessary.
local knownSingleCellGlyphs = {
    "┌", "─", "┐", "│", "└", "┘", "╔", "═", "╗", "║", "╚", "╝"
}

local function width(text)
    local normalized = text
    for _, glyph in ipairs(knownSingleCellGlyphs) do
        normalized = normalized:gsub(glyph, "x")
    end
    return #normalized
end
local function repeatText(text, count) return string.rep(text, math.max(0, count)) end
local function run(text, role) return {text = text, role = role} end

local function append(runs, text, role)
    if text ~= "" then table.insert(runs, run(text, role)) end
end

function Frame.toString(rendered)
    local lines = {}
    for _, line in ipairs(rendered.lines) do
        local text = {}
        for _, item in ipairs(line.runs) do table.insert(text, item.text) end
        table.insert(lines, table.concat(text))
    end
    return table.concat(lines, "\n")
end

function Frame.render(spec)
    Validation.type(spec, "table", "frame")
    Validation.exactKeys(spec, knownFields, "frame")
    Validation.enum(spec.style, styles, "frame.style")
    Validation.type(spec.title, "table", "frame.title")
    Validation.exactKeys(spec.title, {text = true, alignment = true}, "frame.title")
    Validation.type(spec.title.text, "string", "frame.title.text")
    Validation.enum(spec.title.alignment, alignments, "frame.title.alignment")
    Validation.type(spec.padding, "table", "frame.padding")
    Validation.exactKeys(spec.padding, {top = true, bottom = true, left = true, right = true}, "frame.padding")
    for _, side in ipairs({"top", "bottom", "left", "right"}) do
        Validation.nonNegativeInteger(spec.padding[side], "frame.padding." .. side)
    end
    Validation.array(spec.rows, "frame.rows")
    local contentWidth = 0
    for index, row in ipairs(spec.rows) do
        Validation.type(row, "table", "frame.rows[" .. index .. "]")
        Validation.exactKeys(row, {text = true, role = true}, "frame.rows[" .. index .. "]")
        Validation.type(row.text, "string", "frame.rows[" .. index .. "].text")
        Validation.type(row.role, "string", "frame.rows[" .. index .. "].role")
        if row.role == "" then Validation.fail("frame.rows[" .. index .. "].role cannot be empty", 2) end
        contentWidth = math.max(contentWidth, width(row.text))
    end
    local glyphs = styles[spec.style]
    local titleWidth = width(spec.title.text) + 4 -- [ title ]
    local innerWidth = math.max(contentWidth + spec.padding.left + spec.padding.right, titleWidth + 2)
    local lines = {}
    local spare = innerWidth - titleWidth
    local left, right
    if spec.title.alignment == "left" then
        left, right = 1, spare - 1
    elseif spec.title.alignment == "right" then
        left, right = spare - 1, 1
    else
        left = math.floor(spare / 2)
        right = spare - left
    end
    table.insert(lines, {runs = {
        run(glyphs.topLeft .. repeatText(glyphs.horizontal, left) .. "[ ", "frame"),
        run(spec.title.text, "title"),
        run(" ]" .. repeatText(glyphs.horizontal, right) .. glyphs.topRight, "frame")
    }})
    local function contentLine(text, role)
        local runs = {run(glyphs.vertical .. repeatText(" ", spec.padding.left), "frame")}
        append(runs, text, role)
        append(runs,
               repeatText(" ", innerWidth - spec.padding.left - width(text)),
               "frame")
        append(runs, glyphs.vertical, "frame")
        table.insert(lines, {runs = runs})
    end
    for _ = 1, spec.padding.top do contentLine("", "body") end
    for _, row in ipairs(spec.rows) do contentLine(row.text, row.role) end
    for _ = 1, spec.padding.bottom do contentLine("", "body") end
    table.insert(lines, {runs = {run(glyphs.bottomLeft .. repeatText(glyphs.horizontal, innerWidth) .. glyphs.bottomRight, "frame")}})
    return {columns = innerWidth + 2, rows = #lines, lines = lines}
end

return Frame
