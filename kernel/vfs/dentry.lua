-- A dentry object associates an inode with a path in the virtual file system.
local Dentry = {}

function Dentry.new(ind, parent, name)
    return {
        inode = ind,
        parent = parent,
        name  = name
    }
end
