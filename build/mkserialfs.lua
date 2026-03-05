#!/usr/bin/env lua

-- mkserialfs.lua: Convert a directory tree into a SerialFS .dat file.
--
-- Usage: lua mkserialfs.lua <input-dir> > output.dat
-- Example: lua build/mkserialfs.lua rootfs/ > disk.dat

local input_dir = arg[1]

if not input_dir then
    io.stderr:write("Usage: lua mkserialfs.lua <input-dir> > output.dat\n")
    os.exit(1)
end

-- Strip trailing slash so path arithmetic is consistent
input_dir = input_dir:gsub("/$", "")

-- Inode mode values, precomputed from kernel/vfs/inode.lua constants:
--   TYPE_REG(0x8000) | MASK_READ(0x0124) | MASK_WRITE(0x0092) = 0x81B6
--   TYPE_DIR(0x4000) | MASK_PERMS(0x01FF)                     = 0x41FF
local MODE_REG = 0x81B6
local MODE_DIR = 0x41FF

local inode_id = 0
local inodes   = {}
local paths    = {}
local data     = {}

local function alloc_inode(mode, size)
    local id  = inode_id
    inode_id  = inode_id + 1
    local ind = { id = id, links = 0, size = size or 0, owner = 0, group = 0, mode = mode }
    inodes[id] = ind
    return ind
end

-- Convert a host path to its virtual path inside the filesystem
local function vpath(host_path)
    if host_path == input_dir then return "/" end
    return host_path:sub(#input_dir + 1)  -- already starts with "/"
end

local function read_null_list(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then
        io.stderr:write("Error running: " .. cmd .. "\n")
        os.exit(1)
    end
    local raw = handle:read("*a")
    handle:close()
    local items = {}
    for item in raw:gmatch("[^\0]+") do
        items[#items + 1] = item
    end
    table.sort(items)  -- sort so parent dirs are always created before children
    return items
end

-- Quote a path for shell use (single-quote, escape embedded single quotes)
local function shquote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Create root inode
local root = alloc_inode(MODE_DIR)
paths["/"] = root.id

-- Add all directories (excluding the root, which is already handled)
for _, host_path in ipairs(read_null_list("find " .. shquote(input_dir) .. " -mindepth 1 -type d -print0")) do
    local vp = vpath(host_path)
    local inode = alloc_inode(MODE_DIR)
    paths[vp] = inode.id
end

-- Add all regular files
for _, host_path in ipairs(read_null_list("find " .. shquote(input_dir) .. " -type f -print0")) do
    local vp = vpath(host_path)
    local f = assert(io.open(host_path, "rb"), "cannot open " .. host_path)
    local content = f:read("*a")
    f:close()
    local inode = alloc_inode(MODE_REG, #content)
    paths[vp] = inode.id
    data[inode.id] = content
end

-- Serializer — must match the one in kernel/drivers/serialfs.lua
local function serialize(val, indent)
    indent = indent or ""
    local t = type(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        local parts = {}
        local ni = indent .. "  "
        for k, v in pairs(val) do
            local key = type(k) == "string" and k:match("^[%a_][%w_]*$")
                and k or ("[" .. serialize(k) .. "]")
            parts[#parts + 1] = ni .. key .. " = " .. serialize(v, ni)
        end
        if #parts == 0 then return "{}" end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    else
        return "nil"
    end
end

io.write(serialize({
    inode_id = inode_id,
    inodes   = inodes,
    paths    = paths,
    data     = data,
}))
