local TwoWayMap = require("common.two_way_map")
local Inode = require("vfs.inode")
local Paths = require("common.paths")

---@class BaseFS: Driver
---@field arch Arch
---@field inodes table<integer, Inode>
---@field inode_path_map TwoWayMap<string, integer>
---@field inode_id integer
local BaseFS = {}

---@param arch Arch
---@return BaseFS
function BaseFS:new(arch)
    local basefs = {
        arch = arch,
        inodes = {},
        inode_path_map = TwoWayMap:new(),
        inode_id = 0
    }
    setmetatable(basefs, self)
    self.__index = self

    return basefs
end

---@param resolved_path string
---@return Inode
function BaseFS:mount(resolved_path)
    local inode = Inode.create(self.inode_id, Inode.TYPE_DIR, 0, 0)
    self.inode_id = self.inode_id + 1
    self.inodes[inode.id] = inode
    self.inode_path_map:set(resolved_path, inode.id)
    return inode
end

---@param resolved_path string
function BaseFS:unmount(resolved_path)
    local id = self.inode_path_map:get(resolved_path)
    if id then
        self.inodes[id] = nil
        self.inode_path_map:remove(resolved_path)
    end
end

---@param inode Inode
---@return table<integer, string>?
function BaseFS:read_dir(inode)
	local inode_path = self.inode_path_map:get(inode.id)
    if not inode or not Inode.get_file_type(inode, Inode.TYPE_DIR) then
        return nil
    end

    local prefix = inode_path == "/" and "/" or inode_path .. "/"
    local entries = {}
    for path, _ in pairs(self.inode_path_map.forward --[[@as table<string, integer>]]) do
        if path:sub(1, #prefix) == prefix then
            local name = path:sub(#prefix + 1)
            if #name > 0 and not name:find("/", 1, true) then
                entries[#entries + 1] = name
            end
        end
    end
    return entries
end

---@param path string
---@return Inode?
function BaseFS:get_inode(path)
    local id = self.inode_path_map:get(path)
    if id == nil then return nil end
    return self.inodes[id]
end

---@param parent_inode Inode
---@param name string
---@param type integer
---@return Inode
function BaseFS:create_file(parent_inode, name, type)
    -- Create the inode
    local inode = Inode.create(self.inode_id, type, 0, 0)
    self.inode_id = self.inode_id + 1
    self.inodes[inode.id] = inode

    -- Assign the inodes path
    local parent_path = self.inode_path_map:get(parent_inode.id) --[[@as string]]
    self.inode_path_map:set(Paths.join(parent_path, name), inode.id)
    return inode
end

---@param inode Inode
function BaseFS:destroy_file(inode)
    self.inode_path_map:remove(inode.id)
    self.inodes[inode.id] = nil
end

---@param inode Inode
---@param offset integer
---@param length integer
function BaseFS:read_file(inode, offset, length)

end

---@param inode Inode
---@param offset integer
---@param data any
function BaseFS:write_file(inode, offset, data)

end

return BaseFS
