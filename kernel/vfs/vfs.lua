---@class Vfs
---@field mount_table table<string, Driver>
Vfs = {}

function Vfs:new()
    local vfs = {
        mount_table = {},
    }
    setmetatable(vfs, self)
    self.__index = self

    return vfs
end

-- Gets an Inode from the path.
function Vfs:namei(resolved_path)
	local driver = Vfs:get_fs_driver(resolved_path)
	return driver:get_inode(resolved_path)
end

-- Get the filesystem/device that a file is from.
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

-- Mount a device to a path
function Vfs:mount(driver, mount_path)
    self.mount_table[mount_path] = driver
    driver:mount(mount_path)
end

-- Unmount a device
function Vfs:unmount(mount_path)
	self.mount_table[mount_path] = nil
end

function Vfs:read(path, offset, length)
    local driver = Vfs:get_fs_driver(path)
    local inode = driver:get_inode(path)
	return driver:read(inode, offset, length)
end

function Vfs:read_dir(path)
    local driver = Vfs:get_fs_driver(path)
	-- local inode = driver:get
end

function Vfs:write(path, offset, data)
    local driver = Vfs:get_fs_driver(path)
    local inode = driver:get_inode(path)
	return driver:write(inode, offset, data)
end

function Vfs:create(parent_path, name)
    local driver = Vfs:get_fs_driver(parent_path)
    local parent_inode = driver:get_inode(parent_path)
	return driver:create(parent_inode, name)
end
