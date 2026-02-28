RamFS = {}

function RamFS:new(arch)
    local ramfs = {
        arch = arch,
        inodes = {}
    }
    setmetatable(ramfs, self)
    self.__index = self

    return ramfs
end

function RamFS:mount(resolved_path)
	-- self.inodes[resolved_path] = Inode.create(

	-- )
	return self.inodes[resolved_path]
end

function RamFS:unmount(resolved_path)
	self.inodes[resolved_path] = nil
end

function RamFS:read_dir(resolved_path)

end

function RamFS:get_inode(path)

end

function RamFS:create(parent_inode, name)

end

function RamFS:read(inode, offset, length)

end

function RamFS:write(inode, offset, data)

end
