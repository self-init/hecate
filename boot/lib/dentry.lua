-- Dentry kernel library
-- Maps virtual file paths to their inodes.

local dentryMemory = {}

local dentry = {}

local function parseDentryString(dentryString)
    local data = {}

    for entry in (dentryString..":"):gmatch("(.-):") do
        data[#data+1] = entry
    end

    return {
        filePath         = data[1],
        driveLabel       = data[2],
        inode            = tonumber(data[3]),
        parentPath       = data[4],
        parentDriveLabel = data[5],
        parentInode      = tonumber(data[6])
    }
end

function dentry.loadDentryFileToMemory(path)
    local dentryFile = fs.open(path, "r")
    local dentryFileString = dentryFile.readAll()
    dentryFile.close()

    for line in (dentryFileString.."\n"):gmatch("(.-)\n") do
        local parsedDentry = parseDentryString(line)
        dentryMemory[parsedDentry.filePath] = parsedDentry
    end
end

function dentry.getDentryByPath(path)
    return dentryMemory[path]
end

function dentry.createDentry(filePath, driveLabel, inode, parentPath, parentDriveLabel, parentInode)
    dentryMemory[filePath] = {
        filePath = filePath,
        driveLabel = driveLabel,
        inode = inode,
        parentPath = parentPath,
        parentDriveLabel = parentDriveLabel,
        parentInode = parentInode
    }
end

function dentry.getChildren(parentPath)
    local children = {}
    for _,dent in pairs(dentryMemory) do
        if dent.parentPath == parentPath then
            table.insert(children, dent.filePath)
        end
    end
    return children
end

return tabletools.freeze(dentry)