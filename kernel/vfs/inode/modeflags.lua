---@enum InodeModeFlags
local InodeModeFlags = {
	-- [ Inode type flags ]
	TYPE_SCK     = 0xC000, -- Socket
	TYPE_SYM     = 0xA000, -- Symlink
	TYPE_REG     = 0x8000, -- Regular file
	TYPE_BLK     = 0x6000, -- Block device
	TYPE_DIR     = 0x4000, -- Directory
	TYPE_CHR     = 0x2000, -- Character device
	TYPE_PIP     = 0x1000, -- Pipe/FIFO
	-- [ Special flags ]
	IS_SETUID    = 0x0800, -- Setuid
	IS_SETGID    = 0x0400, -- Setgid
	IS_STICKY    = 0x0200, -- Sticky
	-- [ Permission flags ]
	OWNER_READ   = 0x0100, -- Owner Read
	OWNER_WRITE  = 0x0080, -- Owner Write
	OWNER_EXEC   = 0x0040, -- Owner Execute
	GROUP_READ   = 0x0020, -- Group Read
	GROUP_WRITE  = 0x0010, -- Group Write
	GROUP_EXEC   = 0x0008, -- Group Execute
	OTHER_READ   = 0x0004, -- Other Read
	OTHER_WRITE  = 0x0002, -- Other Write
	OTHER_EXEC   = 0x0001, -- Other Execute
	-- [ Bitmasks for inode flags ]
	MASK_SPECIAL = 0x0E00, -- Special bits (setuid, setgid, stick)
	MASK_OWNER   = 0x01C0, -- Owner perms
	MASK_GROUP   = 0x0038, -- Group perms
	MASK_OTHER   = 0x0007, -- Other perms
	MASK_READ    = 0x0124, -- Read perms
	MASK_WRITE   = 0x0092, -- Write perms
	MASK_EXEC    = 0x0049, -- Execute perms
	MASK_PERMS   = 0x01FF, -- All perms (excluding special bits)
	MASK_MODE    = 0x0FFF, -- All perms (including special bits)
	MASK_TYPE    = 0xF000, -- File type
}

return InodeModeFlags
