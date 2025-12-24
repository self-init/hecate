-- Files kernel library
-- Manipulates inodes and dentries to simulate a virtual filesystem.

local files = {}

function buildDriveFs(filePath, mountPath, defaultUser, defaultGroup, defaultPerms, parentInode, parentDriveLabel, parentMountPath)
    local fileType = "-"
    local fileDrive = fs.getDrive(filePath)

    if fs.isDir(filePath) then
        fileType = "d"
    end

    local newInode = inode.createInode(
        fileType, 
        fileDrive, 
        filePath, 
        defaultUser, 
        defaultGroup, 
        defaultPerms
    )

    local dentryParentPath = mountPath
    local parentDrive      = fileDrive
    local parentInodeId    = newInode

    if parentInode ~= nil then
       dentryParentPath = parentMountPath
       parentDrive      = parentDriveLabel
       parentInodeId    = parentInode
    end

    dentry.createDentry(
        mountPath,
        fileDrive,
        newInode,
        dentryParentPath,
        parentDrive,
        parentInodeId
    )

    if fileType ~= "d" then return end
    

    local files = fs.list(filePath)
    for _,file in ipairs(files) do
        local childFilePath = fs.combine(filePath, file)
        if childFilePath:sub(1,1) ~= "/" then
            childFilePath = "/"..childFilePath
        end
        local fileMountPath = fs.combine(mountPath, file)
        if fileMountPath:sub(1,1) ~= "/" then
            fileMountPath = "/"..fileMountPath
        end
        buildDriveFs(childFilePath, fileMountPath, defaultUser, defaultGroup, defaultPerms, newInode, fileDrive, mountPath)
    end
end

files.buildDriveFs = buildDriveFs

function files.initializeDriveFs(path)
    inode.loadInodeFileToMemory(path.."/.inode")
    dentry.loadDentryFileToMemory(path.."/.dentry")
end

function files.cleanFs(path)

end

function files.getPermissions(path, user, groups)
    local fileInode = files.getInodeFromPath(path)
    local permissions = {
        read    = fileInode.perms.all.read,
        write   = fileInode.perms.all.write,
        execute = fileInode.perms.all.execute
    }
    if fileInode.user == user then
        permissions = inode.orPerms(permissions, fileInode.perms.user)
    end
    for _, group in ipairs(groups) do
        if fileInode.group == group then
            permissions = inode.orPerms(permissions, fileInode.perms.group)
        end
    end
    return permissions
end

function files.getAccess(path, user, groups)
    local step = "/"
    for part in path:gmatch("([^/%\\]+)") do
        local canSearch = files.getPermissions(step, user, groups).execute
        if not canSearch then
            return false
        else
            if step == "/" then
                step = step..part
            else
                step = step.."/"..part
            end
        end
    end
    if dentry.getDentryByPath(path) ~= nil then
        return true
    end
    return false
end

function files.resolvePath(path, cwd)
    local pathParts = {}

    -- Use relative path if path doesn't start with "/"
    if path:sub(1,1) ~= "/" then
        for part in cwd:gmatch("([^/%\\]+)") do
            table.insert(pathParts, part)
        end
    end

    for part in path:gmatch("([^/%\\]+)") do
        if part == "." then
            goto continue
        elseif part == ".." then
            table.remove(pathParts, #pathParts)
        else
            table.insert(pathParts, part)
        end

        ::continue::
    end

    local resolvedPath = table.concat(pathParts, "/")
    return "/"..resolvedPath
end

function files.getRealPath(fakePath)
    return files.getInodeFromPath(fakePath).path
end

function files.getInodeFromPath(path)
    local fileDentry = dentry.getDentryByPath(path)
    return inode.getInodeById(fileDentry.driveLabel, fileDentry.inode)
end

function files.open(path, mode)
    --inode.getFileInode(path)
    return fs.open(files.getRealPath(path), mode)
end

function files.readDir(path)
    return dentry.getChildren(path)
end

return files