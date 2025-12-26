local Vfs = {}

function Vfs:new()
    local vfs = {
        mounts = {},
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

end
