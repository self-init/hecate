local FileDescriptorOpenFlags = require("vfs.fd.openflags")
local Bitwise = require("common.bitwise")
local Error   = require("common.error")
local band    = Bitwise.band
local btest   = Bitwise.btest

---@class FileDescriptor
---@field mount  Mount
---@field driver Driver   convenience alias for mount.driver
---@field inode  Inode
---@field path   string   path as given to open (for diagnostics)
---@field offset integer  current file position
---@field flags  integer  open flags
local FileDescriptor = {}

---@param mount  Mount
---@param inode  Inode
---@param path   string
---@param flags  integer
---@return FileDescriptor
function FileDescriptor:new(mount, inode, path, flags)
    local fd = {
        mount  = mount,
        driver = mount.driver,
        inode  = inode,
        path   = path,
        flags  = flags,
        offset = (band(flags, FileDescriptorOpenFlags.O_APPEND) ~= 0) and inode.size or 0,
    }
    setmetatable(fd, self)
    self.__index = self
    inode.refs = inode.refs + 1
    return fd
end

-- Release this file descriptor's reference to its inode.
-- If the inode was unlinked while this was the last reference, frees it now.
function FileDescriptor:close()
    self.inode.refs = self.inode.refs - 1
    if self.inode.refs == 0 and self.inode.unlinked then
        self.driver:_free_inode(self.inode)
    end
end

---@param length integer
---@return any
function FileDescriptor:read(length)
    if btest(self.flags, FileDescriptorOpenFlags.O_DIRECTORY) then
        Error.throw(Error.EISDIR, self.path)
    end
    local data = self.driver:read_file(self.inode, self.offset, length)
    if data ~= nil then
        local n = type(data) == "string" and #data or 0
        self.offset = self.offset + n
    end
    return data
end

---@param data any
---@return integer  bytes written
function FileDescriptor:write(data)
    if btest(self.flags, FileDescriptorOpenFlags.O_DIRECTORY) then
        Error.throw(Error.EISDIR, self.path)
    end
    if band(self.flags, FileDescriptorOpenFlags.O_APPEND) ~= 0 then
        self.offset = self.inode.size
    end
    local n = self.driver:write_file(self.inode, self.offset, data)
    self.offset = self.offset + (n or (type(data) == "string" and #data or 0))
    return n
end

---@param request integer
---@param arg     any
---@return any
function FileDescriptor:ioctl(request, arg)
    return self.driver:ioctl(self.inode, request, arg)
end

---@param offset integer
---@param whence integer  SEEK_SET | SEEK_CUR | SEEK_END
---@return integer  new position
function FileDescriptor:seek(offset, whence)
    if whence == FileDescriptorOpenFlags.SEEK_SET then
        self.offset = offset
    elseif whence == FileDescriptorOpenFlags.SEEK_CUR then
        self.offset = self.offset + offset
    elseif whence == FileDescriptorOpenFlags.SEEK_END then
        self.offset = self.inode.size + offset
    end
    if self.offset < 0 then self.offset = 0 end
    return self.offset
end

return FileDescriptor
