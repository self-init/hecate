local FsDriver = {}

function FsDriver:new(name)
    local fs_driver = {
        name = name,
        mounts = {}
    }
    setmetatable(fs_driver, self)
    self.__index = self

    return fs_driver
end

function FsDriver:mount(device, mount_path)
    error("Not implemented: mount in FsDriver " .. self.name .. ".")
end

function FsDriver:read_dir(device, inode_id)
    error("Not implemented: read_dir in FsDriver " .. self.name .. ".")
end

function FsDriver:get_inode(device, inode_id)
    error("Not implemented: get_inode in FsDriver " .. self.name .. ".")
end

function FsDriver:create_file(device, path, type)
    error("Not implemented: create_file in FsDriver " .. self.name .. ".")
end
