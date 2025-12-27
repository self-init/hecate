local Vfs = {}

function Vfs:new()
    local vfs = {
        superblocks = {},
        inode_cache = {},
        dentry_cache = {}
    }
    setmetatable(vfs, self)
    self.__index = self

    return vfs
end

-- Gets an Inode from the path and working directory.
function Vfs:namei(path, working_directory)
    local working_directory = working_directory or ""

end

-- Get the filesystem/device that a file is from.
function Vfs:get_filesystem(path, working_directory)
    local rpath = Paths.resolve(path, working_directory)
    local matching_mount_path = ""
    local matching_superblock

    for mount_path, superblock in pairs(self.superblocks) do
        if mount_path == rpath:sub(1,#mount_path) and #mount_path > #matching_mount_path then
            matching_mount_path = mount_path
            matching_superblock = superblock
        end
    end

    if matching_superblock == nil then
        error("Error: Vfs get_filesystem: no filesystem associated is associated with the path '" .. rpath .. "'.")
    end

    return matching_superblock
end

-- Mount a device to a path
function Vfs:mount(device, mount_path)
    self.superblocks[mount_path] = device:mount(mount_path)
end
