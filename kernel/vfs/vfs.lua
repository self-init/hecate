local Inode = require("vfs.inode")
local Paths = require("common.paths")

---@class Vfs
---@field mount_table table<string, Driver>
local Vfs = {}

---@return Vfs
function Vfs:new()
    local vfs = {
        mount_table = {},
    }
    setmetatable(vfs, self)
    self.__index = self

    return vfs
end

---Gets an Inode from the path.
---@param resolved_path string
---@return Inode
function Vfs:namei(resolved_path)
	local driver = Vfs:get_fs_driver(resolved_path)
	return driver:get_inode(resolved_path)
end

---Get the filesystem/device that a file is from.
---@param resolved_path string
---@return Driver
function Vfs:get_fs_driver(resolved_path)
    local matching_mount_path = ""
    local matching_driver

    for mount_path, driver in pairs(self.mount_table) do
        if mount_path == resolved_path:sub(1,#mount_path) and #mount_path > #matching_mount_path then
            matching_mount_path = mount_path
            matching_driver = driver
        end
    end

    if matching_driver == nil then
        error("Error: Vfs get_filesystem: no driver associated is associated with the path '" .. resolved_path .. "'.")
    end

    return matching_driver
end

---Mount a device to a path
---@param driver Driver
---@param mount_path string
---@return Inode
function Vfs:mount(driver, mount_path)
    self.mount_table[mount_path] = driver
    return driver:mount(mount_path)
end

---Unmount a device
---@param mount_path string
function Vfs:unmount(mount_path)
	self.mount_table[mount_path] = nil
end

-- Checks execute permission on every parent directory of path.
-- Errors with EACCES if traversal is denied on any directory.
-- Root (euid == 0) bypasses all traversal checks.
---@param process Process
---@param path string
function Vfs:check_path_traversal(process, path)
    if process.euid == 0 then return end
    local gids = process:get_gids()
    for _, dir_path in ipairs(Paths.parent_dirs(path)) do
        local driver = self:get_fs_driver(dir_path)
        local dir_inode = driver:get_inode(dir_path)
        if not Inode.get_perms(dir_inode, Inode.MASK_EXEC, process.euid, gids) then
            error("EACCES: " .. dir_path)
        end
    end
end

-- Checks a permission mask on a single inode for the given process.
-- Errors with EACCES if permission is denied.
-- Root (euid == 0) bypasses all inode permission checks.
---@param process Process
---@param inode Inode
---@param mask integer
---@param path string
function Vfs:check_inode_perm(process, inode, mask, path)
    if process.euid == 0 then return end
    if not Inode.get_perms(inode, mask, process.euid, process:get_gids()) then
        error("EACCES: " .. path)
    end
end

---@param process Process
---@param path string
---@param offset integer
---@param length integer
---@return any
function Vfs:read_file(process, path, offset, length)
    path = Paths.resolve(path, process.current_directory)
    self:check_path_traversal(process, path)
    local driver = self:get_fs_driver(path)
    local inode = driver:get_inode(path)
    self:check_inode_perm(process, inode, Inode.MASK_READ, path)
	return driver:read_file(inode, offset, length)
end

---@param process Process
---@param path string
---@return table<integer, string>
function Vfs:read_dir(process, path)
    path = Paths.resolve(path, process.current_directory)
    self:check_path_traversal(process, path)
    local driver = self:get_fs_driver(path)
    local inode = driver:get_inode(path)
    self:check_inode_perm(process, inode, Inode.MASK_READ, path)
    local entries = driver:read_dir(inode)

    -- Inject names of direct child mount points not already in entries
    local entry_set = {}
    for _, name in ipairs(entries) do entry_set[name] = true end

    local path_prefix = path == "/" and "/" or path .. "/"
    for mount_path, _ in pairs(self.mount_table) do
        if mount_path:sub(1, #path_prefix) == path_prefix then
            local remainder = mount_path:sub(#path_prefix + 1)
            if #remainder > 0 and not remainder:find("/") and not entry_set[remainder] then
                table.insert(entries, remainder)
                entry_set[remainder] = true
            end
        end
    end

    return entries
end

function Vfs:write_file(process, path, offset, data)
    path = Paths.resolve(path, process.current_directory)
    self:check_path_traversal(process, path)
    local driver = self:get_fs_driver(path)
    local inode = driver:get_inode(path)
    self:check_inode_perm(process, inode, Inode.MASK_WRITE, path)
	return driver:write_file(inode, offset, data)
end

function Vfs:create_file(process, parent_path, name, type)
    parent_path = Paths.resolve(parent_path, process.current_directory)
    self:check_path_traversal(process, parent_path)
    local driver = self:get_fs_driver(parent_path)
    local parent_inode = driver:get_inode(parent_path)
    if Inode.get_file_type(parent_inode, Inode.TYPE_DIR) then
        error("ENOTDIR: " .. parent_path)
    end
    self:check_inode_perm(process, parent_inode, Inode.MASK_WRITE, parent_path)
    self:check_inode_perm(process, parent_inode, Inode.MASK_EXEC, parent_path)
	return driver:create_file(parent_inode, name, type)
end

return Vfs
