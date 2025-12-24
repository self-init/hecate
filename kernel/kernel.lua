local Kernel

local function _kernel_new(arch)
    local kernel

    local function _kernel_register_bus()

    end

    local function _kernel_register_device()

    end

    local function _kernel_mount(source, target, fs_type, flags, opts)
        if source ~= "" then

        end

        local new_mount = mount.new(source, mount_path)

        table.insert(self.mounts, new_mount)
    end

    local function _kernel_start()
        -- Start driver core and device enumeration

        -- Register buses

        if kernel.architecture == Kernel.ARCH_COMPUTERCRAFT then
            kernel.register_bus(cc_bus.new("cc_bus"))
            kernel.register_bus(cci_bus.new("cci_bus"))
        end

        -- Mount devtmpfs

        kernel.mount("", "/dev", "tmpfs")

        -- Mount proc/sys

        kernel.mount("", "/sys", "tmpfs")
        kernel.mount("", "/proc", "tmpfs")

        -- Mount real root

        if kernel.architecture == Kernel.ARCH_COMPUTERCRAFT then
            kernel.mount("/dev/hdd", "/", "fsdotfs")
        end

        -- Main loop
    end

    kernel = {
        architecture = arch,
        buses = {},
        devices = {},
        drivers = {},

        filesystems = {},
        mounts = {},
        inode_cache = {},
        dentry_cache = {},
        processes = {},

        register_bus = _kernel_register_bus,
        register_device = _kernel_register_device,
        mount = _kernel_mount,
        start = _kernel_start,
    }

    return kernel
end

Kernel = {
    ARCH_UNKNOWN = 1,
    ARCH_COMPUTERCRAFT = 2,
    ARCH_OPENCOMPUTERS = 3,
    new = _kernel_new
}
