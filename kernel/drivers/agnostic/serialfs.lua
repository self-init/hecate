local BaseFS = require("drivers.common.basefs")
local TwoWayMap = require("common.two_way_map")

---@class SerialFS: BaseFS
---@field host_path string
---@field data table<integer, string>
local SerialFS = BaseFS:new()

---@param arch Arch
---@param host_path string  path on the host filesystem to persist to
---@return SerialFS
function SerialFS:new(arch, host_path)
    local fs = BaseFS.new(self, arch) --[[@as SerialFS]]
    fs.host_path = host_path
    fs.data = {}
    return fs
end

-- Minimal serializer: handles strings, numbers, booleans, and nested tables.
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

function SerialFS:_save()
    local f = assert(io.open(self.host_path, "w"))
    f:write(serialize({
        inode_id = self.inode_id,
        inodes   = self.inodes,
        paths    = self.inode_path_map.forward,
        data     = self.data,
    }))
    f:close()
end

local function _load(host_path)
    local f = io.open(host_path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    local fn = load("return " .. content)
    return fn and fn()
end

-- Override mount: restore state from file if it exists, otherwise initialize fresh.
---@param resolved_path string
---@return Inode
function SerialFS:mount(resolved_path)
    local state = _load(self.host_path)
    if state then
        self.inode_id = state.inode_id
        self.inodes   = state.inodes
        self.data     = state.data
        local map = TwoWayMap:new()
        for path, id in pairs(state.paths) do
            map:set(path, id)
        end
        self.inode_path_map = map
        return self.inodes[self.inode_path_map:get(resolved_path)]
    else
        local inode = BaseFS.mount(self, resolved_path)
        self:_save()
        return inode
    end
end

---@param parent_inode Inode
---@param name string
---@param type integer
---@return Inode
function SerialFS:create_file(parent_inode, name, type)
    local inode = BaseFS.create_file(self, parent_inode, name, type)
    self:_save()
    return inode
end

---@param inode Inode
function SerialFS:destroy_file(inode)
    BaseFS.destroy_file(self, inode)
    if not inode.unlinked then
        -- Inode was freed immediately (no open fds); clean up data now.
        self.data[inode.id] = nil
    end
    self:_save()
end

-- Called by FileDescriptor:close() when the last fd on an unlinked inode closes.
---@param inode Inode
function SerialFS:_free_inode(inode)
    BaseFS._free_inode(self, inode)
    self.data[inode.id] = nil
    self:_save()
end

---@param inode Inode
---@param offset integer
---@param length integer
function SerialFS:read_file(inode, offset, length)
    local contents = self.data[inode.id] or ""
    return contents:sub(offset + 1, offset + length)
end

---@param inode Inode
---@param offset integer
---@param data any
function SerialFS:write_file(inode, offset, data)
    local contents = self.data[inode.id] or ""
    local prefix = contents:sub(1, offset)
    if #prefix < offset then
        prefix = prefix .. string.rep("\0", offset - #prefix)
    end
    local suffix = contents:sub(offset + #data + 1)
    self.data[inode.id] = prefix .. data .. suffix
    inode.size = #self.data[inode.id]
    self:_save()
    return #data
end

return SerialFS
