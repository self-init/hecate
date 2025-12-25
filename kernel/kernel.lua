local Kernel = {
    ARCH_UNKNOWN = 1,
    ARCH_COMPUTERCRAFT = 2,
    ARCH_OPENCOMPUTERS = 3,
}

function Kernel:new(arch)
    local kernel = {
        architecture = arch,
        buses = {},
        devices = {},
        drivers = {},

        filesystems = {},
        mounts = {},
        inode_cache = {},
        dentry_cache = {},
        processes = {}
    }

    setmetatable(kernel, self)
    self.__index = self

    return kernel
end

function Kernel:bus_register(bus)
    table.insert(self.buses, bus)
    -- Iterate over drivers and if one matches, set it as the bus's driver
    for _, driver in ipairs(self.drivers) do
        if TableTools.find(driver.match_table, bus.type) then
            bus.driver = driver
            return
        end
    end
end

function Kernel:driver_register(driver)
    table.insert(self.drivers, driver)
    -- Iterate over buses that don't have a driver, and if they match, set it as that bus's driver
    for _, device in ipairs(self.devices) do
        if device.driver ~= nil then
            if self:match(device, driver) then
                device.driver = driver
            end
        end
    end
end

function Kernel:mount(source, target, fs_type, flags, opts)
    if source ~= "" then

    end

    local new_mount = mount.new(source, mount_path)

    table.insert(self.mounts, new_mount)
end

function Kernel:start()
    -- Start driver core and device enumeration

    -- Mount devtmpfs

    self:mount("", "/dev", "tmpfs")

    -- Mount proc/sys

    self:mount("", "/sys", "tmpfs")
    self:mount("", "/proc", "tmpfs")

    -- Mount real root

    if self.architecture == Kernel.ARCH_COMPUTERCRAFT then
        self:mount("/dev/hdd", "/", "fsdotfs")
    end

    -- Main loop
end
