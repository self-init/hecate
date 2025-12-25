local Vfs = {}

function Vfs:new()
    local vfs = {
        inode_cache = {},
        dentry_cache = {}
    }
    setmetatable(vfs, self)
    self.__index = self

    return vfs
end
