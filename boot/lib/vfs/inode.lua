local inode = {}

                            -- [ Inode type flags ]
inode.TYPE_SCK     = 0xC000 -- Socket
inode.TYPE_SYM     = 0xA000 -- Symlink 
inode.TYPE_REG     = 0x8000 -- Regular file
inode.TYPE_BLK     = 0x6000 -- Block device
inode.TYPE_DIR     = 0x4000 -- Directory
inode.TYPE_CHR     = 0x2000 -- Character device
inode.TYPE_PIP     = 0x1000 -- Pipe/FIFO

                            -- [ Special flags ]
inode.IS_SETUID    = 0x0800 -- Setuid
inode.IS_SETGID    = 0x0400 -- Setgid
inode.IS_STICKY    = 0x0200 -- Sticky

                            -- [ Permission flags ]
inode.OWNER_READ   = 0x0100 -- Owner Read
inode.OWNER_WRITE  = 0x0080 -- Owner Write
inode.OWNER_EXEC   = 0x0040 -- Owner Execute
inode.GROUP_READ   = 0x0020 -- Group Read
inode.GROUP_WRITE  = 0x0010 -- Group Write
inode.GROUP_EXEC   = 0x0008 -- Group Execute
inode.OTHER_READ   = 0x0004 -- Other Read
inode.OTHER_WRITE  = 0x0002 -- Other Write
inode.OTHER_EXEC   = 0x0001 -- Other Execute

                            -- [ Bitmasks for inode flags ]
inode.MASK_SPECIAL = 0x0E00 -- Special bits (setuid, setgid, stick)
inode.MASK_OWNER   = 0x01C0 -- Owner perms
inode.MASK_GROUP   = 0x0038 -- Group perms
inode.MASK_OTHER   = 0x0007 -- Other perms
inode.MASK_READ    = 0x0124 -- Read perms
inode.MASK_WRITE   = 0x0092 -- Write perms
inode.MASK_EXEC    = 0x0049 -- Execute perms
inode.MASK_PERMS   = 0x01FF -- All perms (excluding special bits)
inode.MASK_MODE    = 0x0FFF -- All perms (including special bits)
inode.MASK_TYPE    = 0xF000 -- File type

function inode.new(device, id, fileIdentifier)
    local newInode = {}

    newInode.device = device
    newInode.id = id
    newInode.fileId = fileIdentifier
    newInode.type  = 0
    newInode.links = 0
    newInode.owner = 0
    newInode.group = 0
    newInode.flags = 0x01ff

    function newInode:getPerms(uid, gids)
        local perms = self.flags
        if uid ~= self.owner then
            perms = bit32.band(perms, bit32.bnot(inode.MASK_OWNER))
        end

        local isInGroup = false
        for _,gid in ipairs(gids) do
            if gid == self.group then
                isInGroup = true
                break
            end
        end

        if not isInGroup then
            perms = bit32.band(perms, bit32.bnot(inode.MASK_GROUP))
        end

        return {
            read  = bit32.btest(perms, inode.MASK_READ),
            write = bit32.btest(perms, inode.MASK_WRITE),
            exec  = bit32.btest(perms, inode.MASK_EXEC)
        }
    end

    function newInode:getFileType(flag)
        return bit32.btest(self.flags, flag)
    end

    function newInode:getFile(mode)
        return self.device:getFileFromInode(self, mode)
    end
end

return inode