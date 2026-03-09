local Inode = require("vfs.inode")

---@class BaseChrDev: Driver
---@field path string
---@field inode Inode
---@field coroutine thread
---@field queue table
local BaseChrDev = {}

---@param arch Arch
---@return BaseChrDev
function BaseChrDev:new(arch)
    local bcd = {
        arch = arch,
        path = nil,
        inode = nil,
        coroutine = nil,
        queue = {}
    }
    setmetatable(bcd, self)
    self.__index = self
    return bcd
end


function BaseChrDev:mount(resolved_path)
	self.path = resolved_path
	self.inode = Inode.create(
        0,
        Inode.TYPE_CHR,
        0,
		0
    )
    return self.inode
end

function BaseChrDev:unmount(resolved_path)
    self.path = nil
	self.inode = nil
end

function BaseChrDev:read_dir(resolved_path)

end

function BaseChrDev:get_inode(path)
	return self.inode
end

function BaseChrDev:create_file(parent_inode, name, type)
    error("ENOTDIR: " .. self.path)
end

function BaseChrDev:destroy_file(path)
	if path == self.path then
		self.inode = nil
	end
end

---@param inode Inode
---@param offset integer
---@param length integer
function BaseChrDev:read(inode, offset, length)

end

---@param inode Inode
---@param offset integer
function BaseChrDev:_read_byte(inode, offset)

end

---@param inode Inode
---@param offset integer
---@param data string | table
function BaseChrDev:write(inode, offset, data)

end

function BaseChrDev:_write_byte(inode, offset, byte)

end

return BaseChrDev
