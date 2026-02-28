Kbd = {}

function Kbd:new(arch)
    local kbd = {
        arch = arch,
        path = nil,
        inode = nil,
        coroutine = nil,
        queue = nil
    }
    setmetatable(kbd, self)
    self.__index = self
    return kbd
end

function Kbd:mount(resolved_path)
	self.path = resolved_path
	self.inode = Inode.create(
        0,
        Inode.TYPE_CHR,
        0,
		0
    )
    return self.inode
end

function Kbd:unmount(resolved_path)
    self.path = nil
	self.inode = nil
end

function Kbd:read_dir(resolved_path)

end

function Kbd:get_inode(path)

end

function Kbd:create(parent_inode, name)

end

function Kbd:read(inode, offset, length)
	while #self.queue == 0 do
		coroutine.yield()
	end
	return table.remove(self.queue, 1)
end

function Kbd:write(inode, offset, data)

end
