local vfs = {}

vfs.drivers = {}
vfs.devices = {}
vfs.dentries = {}
vfs.mounts = {}

function vfs.addDriver(driver)
    table.insert(vfs.drivers, driver)
end

function vfs.interpretDriverFromDeviceRoot(deviceRoot)
    for _,driver in ipairs(vfs.drivers) do
        if driver.matchesDeviceRoot(deviceRoot) then
            return driver
        end
    end
end

function vfs.mountDevice(deviceRoot, mountPoint, driver)
    if driver == nil then
        driver = vfs.interpretDriverFromDeviceRoot(deviceRoot)
    end
    vfs.mounts[mountPoint] = driver.mountDevice(deviceRoot)
end

function vfs.formatDevice(deviceRoot, driver)
    local currentDriver = vfs.interpretDriverFromDeviceRoot(deviceRoot)
    driver.format(deviceRoot, currentDriver)
end

function vfs.saveMetaData()
    for _,device in ipairs(vfs.devices) do
        device:saveMetaData()
    end
end

function vfs.getDeviceFromVirtualPath(virtualPath)
    local deepestMountDepth = -1
    local device = nil
    for mountPoint, mountDevice in pairs(vfs.mounts) do
        if virtualPath:sub(1,#mountPoint) == mountPoint then
            local mountPointDepth = paths.getPathDepth(mountPoint)
            if mountPointDepth > deepestMountDepth then
                deepestMountDepth = mountPointDepth
                device = mountDevice
            end
        end
    end
    return device
end

function vfs.getFileInode(virtualPath)
    local device = vfs.getDeviceFromVirtualPath(virtualPath)
    if device == nil then return end
    return device.getFileInode(virtualPath)
end

function vfs.createFile(virtualPath)

end

function vfs.deleteFile(virtualPath)

end