-- New boot process

-- Data structures

-- Inode
-- Each inode represents a file
-- It points to a unique identifier in the file system
-- It also  contains information about the owner of the file, the type of file,
-- and who has read/write/execute permissions for the file
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

function inode.new(device_id, id, file_identifier, file_type, owner, group)
    return {
        device_id = device_id,
        id = id,
        file_identifier = file_identifier,
        type = file_type,
        links = 0,
        owner = owner,
        group = group,
        flags = 0x01FF
    }
end

-- Gets the permissions a user and group (or supplementary groups) has on a file.
-- takes an inode, a mask, and the uid and gids as inputs.
-- rwe_mask should be one of MASK_READ, MASK_WRITE, or MASK_EXEC
-- the function will return true or false depending on the permissions the user/groups have
function inode.get_perms(ind, rwe_mask, uid, gids)
    local perms = ind.flags
    if uid ~= ind.owner then
        perms = bit32.band(perms, bit32.bnot(inode.MASK_OWNER))
    end

    local is_in_group = false
    for _,gid in ipairs(gids) do
        if gid == ind.group then
            is_in_group = true
            break
        end
    end

    if not is_in_group then
        perms = bit32.band(perms, bit32.bnot(inode.MASK_GROUP))
    end

    return bit32.btest(perms, rwe_mask)
end

-- Checks if the file type matches the given type.
-- Flag should be one of the TYPE_* flags
function inode.is_file_type(ind, flag)
    return bit32.btest(ind.flags, flag)
end

-- The device object references a physical device associated with a bus.
local device = {}

function device.new(parent, name, type, bus)
    return {
        parent = parent,
        name   = name,
        type   = type,
        bus    = bus,
    }
end
-- A dentry object associates an inode with a path in the virtual file system.
local dentry = {}

function dentry.new(ind, parent, name)
    return {
        inode = ind,
        parent = parent,
        name = name
    }
end


-- ComputerCraft block device
local cc_blkdev = {}

function cc_blkdev.new(identifier, cc_root)
    local new_device = {
        id = identifier
        root = cc_root
    }

    function new_device:open(path)

    end

    function new_device:release(path)

    end

    function new_device:mkdir(path)

    end

    function newdevice:mkfile(path)

    end

    return new_device
end


-- ComputerCraft device bus
-- Links devices connected directly to the computer and via wired modems
local cc_bus = {}

function cc_bus.new(name)
    assert(peripheral, "Peripheral api does not exist, are you running ComputerCraft?")

    local new_bus = {}

    new_bus.name = name
    new_bus.devices = {}

    function new_bus:scan_devices()
        local devices = peripheral.getNames()
        for _,device_name in ipairs(devices) do
            if self.devices[device_name] == nil then
                local new_device = device.new()
                new_device.parent = self
                new_device.name = device_name
                new_device.type = peripheral.getType(device_name)
                new_device.bus = self
                kernel:device_register(new_device)
            end
        end
    end

    function new_bus:match(device, driver)

    end
end

-- ComputerCraft internal device bus
-- Creates devices for the internal hdd/monitor/keyboard/mouse of the computer
local cci_bus = {}

function cci_bus.new(name)

end
