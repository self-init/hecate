-- Inode kernel library
-- Handles file permissions and paths to real files.

local inodeMemory = {}

local inode = {}

local function parseInodeString(inodeString)
    local data = {}

    for entry in (inodeString..":"):gmatch("(.-):") do
        data[#data+1] = entry
    end

    return {
        id         = tonumber(data[1]),
        type       = data[2],
        driveLabel = data[3],
        path       = data[4],
        user       = tonumber(data[5]),
        group      = tonumber(data[6]),
        perms      = inode.parsePerms(data[7])
    }
end

function inode.loadInodeFileToMemory(path)
    local inodeFile = fs.open(path, "r")
    local inodeFileString = inodeFile.readAll()
    inodeFile.close()

    for line in (inodeFileString.."\n"):gmatch("(.-)\n") do
        local parsedInode = parseInodeString(line)
        if inodeMemory[parsedInode.driveLabel] == nil then
           inodeMemory[parsedInode.driveLabel] = {} 
        end
        inodeMemory[parsedInode.driveLabel][parsedInode.id] = parsedInode
    end
end

function inode.getInodeById(drive, id)
    return inodeMemory[drive][id]
end

function inode.createInode(type, driveLabel, path, user, group, perms)
    if inodeMemory[driveLabel] == nil then
        inodeMemory[driveLabel] = {}
    end

    local id = #inodeMemory[driveLabel]+1

    inodeMemory[driveLabel][id] = {
        id = id,
        type = type,
        driveLabel = driveLabel,
        path = path,
        user = user,
        group = group,
        perms = inode.parsePerms(perms)
    }

    return id
end

function inode.parsePermBit(permBit)
    return {
        read    = bit32.band(permBit, 4) > 0,
        write   = bit32.band(permBit, 2) > 0,
        execute = bit32.band(permBit, 1) > 0
    }
end

function inode.parseSpecialBit(specBit)
    return {
        setuid = bit32.band(specBit, 4) > 0,
        setgid = bit32.band(specBit, 2) > 0,
        sticky = bit32.band(specBit, 1) > 0
    }
end

function inode.parsePerms(perms)
    local permChars = {}

    for char in perms:gmatch(".") do
        permChars[#permChars+1] = tonumber(char)
    end

    return {
        special = inode.parseSpecialBit(permChars[1]),
        user    = inode.parsePermBit(permChars[2]),
        group   = inode.parsePermBit(permChars[3]),
        all     = inode.parsePermBit(permChars[4])
    }
end

function inode.orPerms(perm1, perm2)
    return {
        read = perm1.read or perm2.read,
        write = perm1.write or perm2.write,
        execute = perm1.execute or perm2.execute
    }
end

function inode.setPerms(id, perms)
    inodeMemory[id].perms = perms
end

function inode.getUserPerms(uid)

end

function inode.suidIsSet(inode)

end

function inode.guidIsSet(inode)

end

return tabletools.freeze(inode)