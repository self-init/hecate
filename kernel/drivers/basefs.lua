local TwoWayMap = require("common.two_way_map")
local Inode = require("vfs.inode")
local Paths = require("common.paths")

---@class BaseFS: Driver
---@field arch Arch
---@field inodes table<integer, Inode>
---@field inode_path_map TwoWayMap<string, integer>
---@field inode_id integer
BaseFS = {}

function BaseFS:new(arch)
    local ramfs = {
        arch = arch,
        inodes = {},
        inode_path_map = TwoWayMap:new(),
        inode_id = 0
    }
    setmetatable(ramfs, self)
    self.__index = self

    return ramfs
end

function BaseFS:mount(resolved_path)
    local inode = Inode.create(self.inode_id, Inode.TYPE_DIR, 0, 0)
    self.inode_id = self.inode_id + 1
    self.inodes[inode.id] = inode
    self.inode_path_map:set(resolved_path, inode.id)
    return inode
end

function BaseFS:unmount(resolved_path)
    local id = self.inode_path_map:get(resolved_path)
    if id then
        self.inodes[id] = nil
        self.inode_path_map:remove(resolved_path)
    end
end

---@param resolved_path string
function BaseFS:read_dir(resolved_path)
    local inode = self:get_inode(resolved_path)
    if not inode or inode.type ~= Inode.TYPE_DIR then
        return nil
    end

    local entries = {}
    for path, id in pairs(self.inode_path_map.forward) do
        if path:sub(1, #resolved_path + 1) == resolved_path .. "/" then
            entries[#entries + 1] = path:sub(#resolved_path + 2)
        end
    end
    return entries
end

---@param path string
function BaseFS:get_inode(path)
    local id = self.inode_path_map:get(path)
    if id == nil then return nil end
    return self.inodes[id]
end


function BaseFS:create_file(parent_inode, name, type)
    -- Create the inode
    local inode = Inode.create(self.inode_id, type, 0, 0)
    self.inode_id = self.inode_id + 1
    self.inodes[inode.id] = inode

    -- Assign the inodes path
    local parent_path = self.inode_path_map:get(parent_inode.id)
    self.inode_path_map:set(Paths.join(parent_path, name), inode.id)
    return inode
end

function BaseFS:destroy_file(path)
    local id = self.inode_path_map:get(path)
    if not id then return end
    self.inode_path_map:remove(path)
    self.inodes[id] = nil
end

---@param inode Inode
---@param offset integer
---@param length integer
function BaseFS:read(inode, offset, length)

end

---@param inode Inode
---@param offset integer
---@param data any
function BaseFS:write(inode, offset, data)

end

return BaseFS
