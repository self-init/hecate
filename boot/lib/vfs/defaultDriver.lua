local driver = {}

driver.mounts = {}

function driver:mountDevice(deviceRoot, mountPoint)
    -- Reuse the device if it already exists
    if driver.mounts[deviceRoot] ~= nil then
        table.insert(driver.mounts[deviceRoot].mountPoints, mountPoint)
        return driver.mounts[deviceRoot]
    end

    local device = {}

    device.deviceRoot = {}
    device.serial = {}
    device.mountPoints = {mountPoint}

    device.inodes = {}
    device.dentries = {}

    function device:loadMetaData()

    end

    function device:saveMetaData()

    end

    -- Trims the deepest matching mount point from the beginning of the file and adds the device root to it.
    function device:translateVirtualPath(virtualPath)
        local deepestMountDepth = -1
        local deepestPoint = nil
        for _,mountPoint in ipairs(self.mountPoints) do
            if virtualPath:sub(1,#mountPoint) == mountPoint then
                if #mountPoint > deepestMountDepth then
                    deepestMountDepth = #mountPoint
                    deepestPoint = mountPoint
                end
            end
        end
        if deepestPoint ~= nil then
            return paths.join(self.deviceRoot,virtualPath:sub(#deepestPoint))
        end
        return nil
    end

    function device:newInode(path)
        if path:sub(1,#self.deviceRoot) ~= self.deviceRoot then
            path = self:translateVirtualPath(path)
        end

        local inodeId = #self.inodes
        self.inodes[inodeId] = inode.new(device, inodeId, path)
        return self.inodes[inodeId]
    end

    function device:newDentry(virtualPath, inode)
        self.dentries[virtualPath] = inode
    end

    function device:getFileFromInode(inode, mode)
        
    end
end