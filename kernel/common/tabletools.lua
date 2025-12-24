-- Tabletools kernel library
-- Tools used for manipulating tables
local TableTools

local function _tabletools_freeze(original_table)
    local proxy = {}
    local mt = {
        __index = original_table,
        __newindex = function(t, key, value)
            error("Attempt to modify a read-only table.", 2)
        end,

        __metatable = "Metatable is protected"
    }

    return setmetatable(proxy, mt)
end

local function _tabletools_shallowcopy(original)
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = v
    end
    return copy
end

local function _tabletools_deepcopy(orig, seen)
    seen = seen or {} -- Table to track already-copied tables to handle cycles
    if type(orig) ~= 'table' then
        return orig -- Non-tables are returned directly
    end
    if seen[orig] then
        return seen[orig] -- Return already-copied table if a cycle is detected
    end

    local copy = {}
    seen[orig] = copy -- Mark the new table as seen before populating

    -- Copy keys and values recursively
    for k, v in pairs(orig) do
        copy[tabletools.deepcopy(k, seen)] = tabletools.deepcopy(v, seen)
    end

    -- Copy the metatable if it exists
    local mt = getmetatable(orig)
    if mt then
        setmetatable(copy, tabletools.deepcopy(mt, seen))
    end

    return copy
end

local function _tabletools_find(t, search)
    for index, value in ipairs(t) do
        if search == value then return index end
    end
    return -1
end

TableTools = {
    freeze = _tabletools_freeze,
    shallowcopy = _tabletools_shallowcopy,
    deepcopy = _tabletools_deepcopy,
    find = _tabletools_find
}
