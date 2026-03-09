local Bitwise = require("common.bitwise")
local band = Bitwise.band

---@class FileDescriptor
---@field inode  Inode
---@field driver Driver
---@field path   string   resolved path (for diagnostics)
---@field offset integer  current file position
---@field flags  integer  open flags
local FileDescriptor = {}

-- Open flags
FileDescriptor.O_RDONLY   = 0x0000
FileDescriptor.O_WRONLY   = 0x0001
FileDescriptor.O_RDWR     = 0x0002
FileDescriptor.O_CREAT    = 0x0040
FileDescriptor.O_TRUNC    = 0x0200
FileDescriptor.O_APPEND   = 0x0400
FileDescriptor.O_NONBLOCK = 0x0800
-- IMPLEMENT O_NONBLOCK FOR BLOCKING/NONBLOCKING READ AND WRITE


-- Seek whence
FileDescriptor.SEEK_SET = 0
FileDescriptor.SEEK_CUR = 1
FileDescriptor.SEEK_END = 2

---@param driver Driver
---@param inode  Inode
---@param path   string
---@param flags  integer
---@return FileDescriptor
function FileDescriptor:new(driver, inode, path, flags)
    local fd = {
        driver = driver,
        inode  = inode,
        path   = path,
        flags  = flags,
        offset = (band(flags, FileDescriptor.O_APPEND) ~= 0) and inode.size or 0,
    }
    setmetatable(fd, self)
    self.__index = self
    return fd
end

---@param length integer
---@return any
function FileDescriptor:read(length)
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
    if band(self.flags, FileDescriptor.O_APPEND) ~= 0 then
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
    if whence == FileDescriptor.SEEK_SET then
        self.offset = offset
    elseif whence == FileDescriptor.SEEK_CUR then
        self.offset = self.offset + offset
    elseif whence == FileDescriptor.SEEK_END then
        self.offset = self.inode.size + offset
    end
    if self.offset < 0 then self.offset = 0 end
    return self.offset
end

return FileDescriptor
