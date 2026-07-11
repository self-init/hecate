local InodeModeFlags = require("vfs.inode.modeflags")
local Bitwise = require("common.bitwise")

-- Inode
-- See inode(7) for more information
-- Each inode represents a file
-- It points to a unique identifier in the file system
-- It also  contains information about the owner of the file, the type of file,
-- and who has read/write/execute permissions for the file
---@class Inode
---@field id integer
---@field links integer
---@field owner integer
---@field group integer
---@field mode integer
---@field size integer
local Inode = {}

---@param id number
---@param file_type InodeModeFlags
---@param owner number
---@param group number
function Inode.create(id, file_type, owner, group)
	-- default to 666 perms
    local default_mode = Bitwise.bor(InodeModeFlags.MASK_READ, InodeModeFlags.MASK_WRITE)

    -- directories get 777 perms
	if file_type == InodeModeFlags.TYPE_DIR then
		default_mode = InodeModeFlags.MASK_PERMS
	end

	return {
        id       = id,
        links    = 1,       -- number of directory entries pointing to this inode
        size     = 0,
        refs     = 0,       -- count of open FileDescriptors referencing this inode
        unlinked = false,   -- true if destroy_file was called while refs > 0
        owner    = owner,
        group    = group,
        mode     = Bitwise.bor(file_type, default_mode),
    }
end

function Inode.get_perms(ind, rwe_mask, uid, gids)
    local perms = ind.mode
    if uid ~= ind.owner then
        perms = Bitwise.band(perms, Bitwise.bnot(InodeModeFlags.MASK_OWNER))
    end

    local is_in_group = false
    for _,gid in ipairs(gids) do
        if gid == ind.group then
            is_in_group = true
            break
        end
    end

    if not is_in_group then
        perms = Bitwise.band(perms, Bitwise.bnot(InodeModeFlags.MASK_GROUP))
    end

    return Bitwise.btest(perms, rwe_mask)
end

function Inode.get_file_type(ind, flag)
     return Bitwise.btest(ind.mode, flag)
end

return Inode
