local Mount = require("vfs.mount")
local Inode = require("vfs.inode")
local InodeModeFlags = require("vfs.inode.modeflags")
local Error = require("common.error")

---@class Vfs
---@field root_mount Mount
local Vfs = {}

---@return Vfs
function Vfs:new()
    local vfs = {
        root_mount = nil,
    }
    setmetatable(vfs, self)
    self.__index = self
    return vfs
end

-- Walk a path component by component, resolving mounts and permissions.
-- Returns (mount, inode) for the final path component.
-- inode is nil when the final component does not exist (mount is the parent's mount).
-- cred may be nil for kernel context (skips all permission checks).
-- cwd_mount/cwd_inode supply the starting point for relative paths.
---@param path      string
---@param cred      Credentials?
---@param cwd_mount Mount?
---@param cwd_inode Inode?
---@return Mount, Inode?
function Vfs:namei(path, cred, cwd_mount, cwd_inode)
    local cur_mount, cur_inode

    if path:sub(1, 1) == "/" then
        cur_mount = self.root_mount
        cur_inode = self.root_mount.root_inode
    else
        cur_mount = cwd_mount or self.root_mount
        cur_inode = cwd_inode or self.root_mount.root_inode
    end

    for component in path:gmatch("([^/]+)") do
        if component == "." then
            -- Stay at current inode.

        elseif component == ".." then
            -- Are we at the root of the current mount?
            if cur_inode.id == cur_mount.root_inode.id then
                if cur_mount.parent then
                    -- Cross mount boundary upward: land on the mountpoint inode
                    -- in the parent filesystem, then apply ".." from there.
                    local mp_inode = cur_mount.mountpoint_inode
                    cur_mount = cur_mount.parent
                    if mp_inode.id ~= cur_mount.root_inode.id then
                        local parent_inode = cur_mount.driver:lookup(mp_inode, "..")
                        cur_inode = parent_inode or cur_mount.root_inode
                    else
                        cur_inode = cur_mount.root_inode
                    end
                end
                -- else: ".." at the true root is a no-op (POSIX behaviour).
            else
                local parent_inode = cur_mount.driver:lookup(cur_inode, "..")
                if parent_inode then cur_inode = parent_inode end
            end

        else
            -- Check execute permission on the directory being traversed.
            if cred then
                self:check_inode_perm(cred, cur_inode, InodeModeFlags.MASK_EXEC, component)
            end

            local next_inode = cur_mount.driver:lookup(cur_inode, component)
            if next_inode == nil then
                -- Component not found; return the mount context so callers
                -- can create files here (e.g. O_CREAT).
                return cur_mount, nil
            end

            -- Cross into a child mount if one is attached to this inode.
            local child_mount = cur_mount.children[next_inode.id]
            if child_mount then
                cur_mount = child_mount
                cur_inode = child_mount.root_inode
            else
                cur_inode = next_inode
            end
        end
    end

    return cur_mount, cur_inode
end

-- Check a permission mask on a single inode. Root (euid == 0) always passes.
---@param cred  Credentials
---@param inode Inode
---@param mask  integer
---@param path  string   used in the error message
function Vfs:check_inode_perm(cred, inode, mask, path)
    if cred.euid == 0 then return end
    if not Inode.get_perms(inode, mask, cred.euid, cred:get_gids()) then
        Error.throw(Error.EACCES, path)
    end
end

-- Mount a driver at mount_path.
-- For the root mount ("/") this initialises root_mount.
-- For all other paths the mountpoint directory must already exist.
---@param driver     Driver
---@param mount_path string
---@return Inode  root inode of the new mount
function Vfs:mount(driver, mount_path)
    local root_inode = driver:mount(mount_path)

    if mount_path == "/" then
        self.root_mount = Mount:new(driver, nil, nil, root_inode)
    else
        local parent_mount, mp_inode = self:namei(mount_path, nil, nil, nil)
        if mp_inode == nil then
            Error.throw(Error.ENOENT, mount_path)
        end
        local new_mount = Mount:new(driver, parent_mount, mp_inode, root_inode)
        parent_mount.children[mp_inode.id] = new_mount
    end

    return root_inode
end

-- Unmount the filesystem at mount_path.
---@param mount_path string
function Vfs:unmount(mount_path)
    if mount_path == "/" then
        self.root_mount = nil
        return
    end
    local parent_mount, mp_inode = self:namei(mount_path, nil, nil, nil)
    if mp_inode and parent_mount.children[mp_inode.id] then
        parent_mount.children[mp_inode.id] = nil
    end
end

---@param process Process
---@param path    string
---@param offset  integer
---@param length  integer
---@return any
function Vfs:read_file(process, path, offset, length)
    local mount, inode = self:namei(path, process.cred, process.cwd_mount, process.cwd_inode)
    if inode == nil then Error.throw(Error.ENOENT, path) end
    self:check_inode_perm(process.cred, inode, InodeModeFlags.MASK_READ, path)
    return mount.driver:read_file(inode, offset, length)
end

---@param process Process
---@param path    string
---@return table<integer, string>
function Vfs:read_dir(process, path)
    local mount, inode = self:namei(path, process.cred, process.cwd_mount, process.cwd_inode)
    if inode == nil then Error.throw(Error.ENOENT, path) end
    self:check_inode_perm(process.cred, inode, InodeModeFlags.MASK_READ, path)
    local entries = mount.driver:read_dir(inode)

    -- Inject "." and ".." if the driver did not supply them.
    local entry_set = {}
    for _, name in ipairs(entries) do entry_set[name] = true end
    if not entry_set["."]  then table.insert(entries, ".")  end
    if not entry_set[".."] then table.insert(entries, "..") end

    return entries
end

function Vfs:write_file(process, path, offset, data)
    local mount, inode = self:namei(path, process.cred, process.cwd_mount, process.cwd_inode)
    if inode == nil then Error.throw(Error.ENOENT, path) end
    self:check_inode_perm(process.cred, inode, InodeModeFlags.MASK_WRITE, path)
    return mount.driver:write_file(inode, offset, data)
end

function Vfs:create_file(process, parent_path, name, type)
    local mount, parent_inode = self:namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode)
    if parent_inode == nil then Error.throw(Error.ENOENT, parent_path) end
    if not Inode.get_file_type(parent_inode, InodeModeFlags.TYPE_DIR) then
        Error.throw(Error.ENOTDIR, parent_path)
    end
    self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path)
    self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path)
    return mount.driver:create_file(parent_inode, name, type)
end

-- Remove a file. Errors if path is a directory (use rmdir instead).
function Vfs:unlink(process, path)
    local mount, inode = self:namei(path, process.cred, process.cwd_mount, process.cwd_inode)
    if inode == nil then Error.throw(Error.ENOENT, path) end
    if Inode.get_file_type(inode, InodeModeFlags.TYPE_DIR) then
        Error.throw(Error.EISDIR, path)
    end
    local parent_path = path:match("^(.+)/[^/]+$") or (path:sub(1,1) == "/" and "/" or ".")
    local _, parent_inode = self:namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode)
    if parent_inode then
        self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path)
        self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path)
    end
    mount.driver:destroy_file(inode)
end

-- Create a directory.
function Vfs:mkdir(process, path)
    local name = path:match("[^/]+$") or path
    local parent_path = path:match("^(.+)/[^/]+$") or (path:sub(1,1) == "/" and "/" or ".")
    local mount, parent_inode = self:namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode)
    if parent_inode == nil then Error.throw(Error.ENOENT, parent_path) end
    if not Inode.get_file_type(parent_inode, InodeModeFlags.TYPE_DIR) then
        Error.throw(Error.ENOTDIR, parent_path)
    end
    self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path)
    self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path)
    -- Confirm target does not already exist.
    local _, existing = self:namei(path, process.cred, process.cwd_mount, process.cwd_inode)
    if existing ~= nil then Error.throw(Error.EEXIST, path) end
    return mount.driver:create_file(parent_inode, name, InodeModeFlags.TYPE_DIR)
end

-- Remove an empty directory.
function Vfs:rmdir(process, path)
    local mount, inode = self:namei(path, process.cred, process.cwd_mount, process.cwd_inode)
    if inode == nil then Error.throw(Error.ENOENT, path) end
    if not Inode.get_file_type(inode, InodeModeFlags.TYPE_DIR) then
        Error.throw(Error.ENOTDIR, path)
    end
    local entries = mount.driver:read_dir(inode)
    if entries and #entries > 0 then Error.throw(Error.ENOTEMPTY, path) end
    local parent_path = path:match("^(.+)/[^/]+$") or (path:sub(1,1) == "/" and "/" or ".")
    local _, parent_inode = self:namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode)
    if parent_inode then
        self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path)
        self:check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path)
        -- Removing a directory also removes its .. back-reference.
        parent_inode.links = parent_inode.links - 1
    end
    mount.driver:destroy_file(inode)
end

return Vfs
