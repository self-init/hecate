local Bitwise = require("common.bitwise")

-- Inode
-- See inode(7) for more information
-- Each inode represents a file
-- It points to a unique identifier in the file system
-- It also  contains information about the owner of the file, the type of file,
-- and who has read/write/execute permissions for the file
---@class Inode
---@field id integer
---@field owner integer
---@field group integer
---@field mode integer
---@field size integer
local Inode = {
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

---@param id number
---@param file_type number
---@param owner number
---@param group number
function Inode.create(id, file_type, owner, group)
	-- default to 666 perms
    local default_mode = Bitwise.bor(Inode.MASK_READ, Inode.MASK_WRITE)

    -- directories get 777 perms
	if file_type == Inode.TYPE_DIR then
		default_mode = Inode.MASK_PERMS
	end

	return {
        id = id,
        links = 0,
        size = 0,
        owner = owner,
        group = group,
        mode = Bitwise.bor(file_type, default_mode),
    }
end

function Inode.get_perms(ind, rwe_mask, uid, gids)
    local perms = ind.mode
    if uid ~= ind.owner then
        perms = Bitwise.band(perms, Bitwise.bnot(Inode.MASK_OWNER))
    end

    local is_in_group = false
    for _,gid in ipairs(gids) do
        if gid == ind.group then
            is_in_group = true
            break
        end
    end

    if not is_in_group then
        perms = Bitwise.band(perms, Bitwise.bnot(Inode.MASK_GROUP))
    end

    return Bitwise.btest(perms, rwe_mask)
end

function Inode.get_file_type(ind, flag)
     return Bitwise.btest(ind.mode, flag)
end

return Inode
