---@class Tty: Driver
Tty = {}

function Tty:new(arch)
    local tty = {
        arch = arch,
        path = nil,
        inode = nil
    }
    setmetatable(tty, self)
    self.__index = self
    return tty
end

function Tty:mount(resolved_path)
	self.path = resolved_path
	self.inode = Inode.create(
        0,
        Inode.TYPE_CHR,
        0,
		0
    )
	return self.inode
end

function Tty:unmount(resolved_path)
    self.path = nil
	self.inode = nil
end

function Tty:read_dir(resolved_path)

end

function Tty:get_inode(path)

end

function Tty:create(parent_inode, name)

end

function Tty:read(inode, offset, length)

end

function Tty:write(inode, offset, data)
	self.arch:tty_write(data)
end
