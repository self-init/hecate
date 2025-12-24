-- A dentry object associates an inode with a path in the virtual file system.
local Dentry

local function _dentry_new(ind, parent, name)
    return {
        inode = ind,
        parent = parent,
        name  = name
    }
end

Dentry = {
    new = _dentry_new
}
