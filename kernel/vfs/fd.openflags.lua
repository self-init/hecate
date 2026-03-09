---@enum FileDescriptorOpenFlags
local FileDescriptorOpenFlags = {
	-- Open flags
	O_RDONLY   = 0x0000,
	O_WRONLY   = 0x0001,
	O_RDWR     = 0x0002,
	O_CREAT    = 0x0040,
	O_TRUNC    = 0x0200,
	O_APPEND   = 0x0400,
	O_NONBLOCK = 0x0800,
	-- IMPLEMENT O_NONBLOCK FOR BLOCKING/NONBLOCKING READ AND WRITE


	-- Seek whence
	SEEK_SET = 0,
	SEEK_CUR = 1,
	SEEK_END = 2
}

return FileDescriptorOpenFlags
