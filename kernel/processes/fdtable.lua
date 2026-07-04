local FileDescriptorOpenFlags = require("vfs.fd.openflags")
local Bitwise = require("common.bitwise")
local btest   = Bitwise.btest

---@class FDTable
---@field _fds table<number, FileDescriptor>
local FDTable = {}

function FDTable:new()
	local t = { _fds = {} }
	setmetatable(t, self)
	self.__index = self
	return t
end

-- Get the FileDescriptor at slot n, or nil if not open.
---@param n number
---@return FileDescriptor?
function FDTable:get(n)
	return self._fds[n]
end

-- Assign a FileDescriptor to a specific slot (used for stdin/stdout/stderr).
---@param n number
---@param fd FileDescriptor
function FDTable:set(n, fd)
	self._fds[n] = fd
end

-- Close the fd at slot n, releasing its inode reference.
---@param n number
function FDTable:close(n)
	local fd = self._fds[n]
	if fd then
		fd:close()
		self._fds[n] = nil
	end
end

-- Close all fds that were opened with O_CLOEXEC. Called on exec().
function FDTable:close_cloexec()
	local to_close = {}
	for n, fd in pairs(self._fds) do
		if btest(fd.flags, FileDescriptorOpenFlags.O_CLOEXEC) then
			table.insert(to_close, n)
		end
	end
	for _, n in ipairs(to_close) do
		self:close(n)
	end
end

-- Insert a FileDescriptor at the lowest available slot >= 3. Returns the slot number.
---@param fd FileDescriptor
---@return number
function FDTable:insert(fd)
    local n = 3
    while self._fds[n] do n = n + 1 end
    self._fds[n] = fd
    return n
end

-- Pulls fds 0, 1, and 2 from an fdtable into this fdtable
function FDTable:inherit(fdtable)
	for i = 0, 2, 1 do
		self:set(i, fdtable:get(1))
	end
end

return FDTable
