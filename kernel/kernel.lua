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

function Kernel:bus_register()

end

function Kernel:device_register()

end

function Kernel:mount(source, target, fs_type, flags, opts)
    if source ~= "" then

    end

    local new_mount = mount.new(source, mount_path)

    table.insert(self.mounts, new_mount)
end

function Kernel:start()
    -- Start driver core and device enumeration

    -- Register buses

    if self.architecture == Kernel.ARCH_COMPUTERCRAFT then
        self:register_bus(cc_bus.new("cc_bus"))
        self:register_bus(cci_bus.new("cci_bus"))
    end

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
