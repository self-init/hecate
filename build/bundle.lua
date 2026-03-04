#!/usr/bin/env lua

-- bundle.lua: Bundles multiple Lua files into a single distributable file.
--
-- Usage: lua bundle.lua <entry_point.lua> [search_dir] > output.lua
--   entry_point.lua  The main Lua file to start bundling from.
--   search_dir       Directory to search for modules (default: directory of entry point).
--
-- Example: lua bundle.lua src/main.lua src/ > dist/game.lua

local entry_file = arg[1]
local search_dir = arg[2]

if not entry_file then
    io.stderr:write("Usage: lua bundle.lua <entry_point.lua> [search_dir]\n")
    os.exit(1)
end

-- Derive search_dir from entry file path if not provided
if not search_dir then
    search_dir = entry_file:match("^(.*[/\\])") or "./"
end

-- Normalise search_dir to always end with a slash
if not search_dir:match("[/\\]$") then
    search_dir = search_dir .. "/"
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Read the full contents of a file
local function read_file(path)
    local f, err = io.open(path, "r")
    if not f then return nil, err end
    local content = f:read("*a")
    f:close()
    return content
end

-- Convert a module name like "utils.helpers" → "utils/helpers.lua"
local function module_to_path(mod_name)
    return search_dir .. mod_name:gsub("%.", "/") .. ".lua"
end

-- Scan Lua source for require() calls and return a list of module names.
-- Handles:  require("mod")  require('mod')  require [[mod]]
local function find_requires(source)
    local deps = {}
    local seen = {}
    for mod in source:gmatch('[^-]-require%s*%(%s*["\']([^"\']+)["\']%s*%)') do
        if not seen[mod] then
            seen[mod] = true
            deps[#deps + 1] = mod
        end
    end
    -- Long-string form: require [[modname]]
    for mod in source:gmatch('[^-]-require%s*%[%[([^%]]+)%]%]') do
        if not seen[mod] then
            seen[mod] = true
            deps[#deps + 1] = mod
        end
    end
    return deps
end

-- ── Dependency resolution (topological sort / DFS) ───────────────────────────

local resolved   = {}   -- ordered list of module names
local resolved_s = {}   -- set for dedup
local visiting   = {}   -- cycle detection
local sources    = {}   -- module name → source code

local function resolve(mod_name)
    if resolved_s[mod_name] then return end
    if visiting[mod_name] then
        io.stderr:write("Warning: circular dependency detected at '" .. mod_name .. "'\n")
        return
    end

    local path = module_to_path(mod_name)
    local src, err = read_file(path)
    if not src then
        -- Not a local module (e.g. a system library) — skip it
        io.stderr:write("Skipping external/missing module: " .. mod_name .. " (" .. err .. ")\n")
        return
    end

    sources[mod_name] = src
    visiting[mod_name] = true

    for _, dep in ipairs(find_requires(src)) do
        resolve(dep)
    end

    visiting[mod_name] = nil
    resolved_s[mod_name] = true
    resolved[#resolved + 1] = mod_name
end

-- ── Process entry point ───────────────────────────────────────────────────────

local entry_src, err = read_file(entry_file)
if not entry_src then
    io.stderr:write("Error reading entry file: " .. err .. "\n")
    os.exit(1)
end

-- Resolve all dependencies found in the entry file
for _, dep in ipairs(find_requires(entry_src)) do
    resolve(dep)
end

-- ── Emit bundled output ───────────────────────────────────────────────────────

io.write("-- Bundled by bundle.lua\n")
io.write("-- DO NOT EDIT — edit the source files and re-run bundle.lua\n\n")

-- Emit each dependency wrapped in package.preload so require() works normally
for _, mod_name in ipairs(resolved) do
    io.write(string.format(
        'package.preload[%q] = function(...)\n%s\nend\n\n',
        mod_name,
        sources[mod_name]
    ))
end

-- Emit the entry point inline (not wrapped — it runs immediately)
io.write("-- Entry point: " .. entry_file .. "\n")
io.write(entry_src)
io.write("\n")
