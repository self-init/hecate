local TwoWayMap = require("common.two_way_map")
local Inode = require("vfs.inode")
local InodeModeFlags = require("vfs.inode.modeflags")
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
    local inode = Inode.create(self.inode_id, InodeModeFlags.TYPE_DIR, 0, 0)
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
    if not inode or not Inode.get_file_type(inode, InodeModeFlags.TYPE_DIR) then
        return nil
    end
	local inode_path = self.inode_path_map:get(inode.id)

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

-- Look up a name inside a directory inode.
-- Handles ".." by walking to the parent path.
-- Returns nil if the name does not exist.
---@param dir_inode Inode
---@param name string
---@return Inode?
function BaseFS:lookup(dir_inode, name)
    local dir_path = self.inode_path_map:get(dir_inode.id)
    if dir_path == nil then return nil end
    if name == ".." then
        local parent_path = dir_path:match("^(.*)/[^/]+$") or "/"
        return self:get_inode(parent_path)
    end
    return self:get_inode(Paths.join(dir_path, name))
end

---@param parent_inode Inode
---@param name string
---@param type integer
---@return Inode
function BaseFS:create_file(parent_inode, name, type)
    local inode = Inode.create(self.inode_id, type, 0, 0)
    self.inode_id = self.inode_id + 1
    self.inodes[inode.id] = inode

    local parent_path = self.inode_path_map:get(parent_inode.id) --[[@as string]]
    self.inode_path_map:set(Paths.join(parent_path, name), inode.id)

    -- A new directory contains a .. entry pointing back to its parent,
    -- so the parent gains one more link.
    if type == InodeModeFlags.TYPE_DIR then
        parent_inode.links = parent_inode.links + 1
    end

    return inode
end

---@param inode Inode
function BaseFS:destroy_file(inode)
    inode.links = inode.links - 1
    self.inode_path_map:remove(inode.id)
    if inode.links == 0 and inode.refs == 0 then
        self.inodes[inode.id] = nil
    elseif inode.links == 0 then
        -- Open fds still reference this inode. Mark it unlinked so the last
        -- fd to close will free it via _free_inode().
        inode.unlinked = true
    end
    -- links > 0 means other directory entries still point here (hard links).
    -- The inode stays alive; only the path entry was removed.
end

-- Free an inode's storage. Called by FileDescriptor:close() when the last
-- reference drops on an already-unlinked inode.
---@param inode Inode
function BaseFS:_free_inode(inode)
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
