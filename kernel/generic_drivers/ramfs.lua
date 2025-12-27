local RamFs = FsDriver:new("ramfs")

function RamFs:mount(device, mount_path)
    self.mounts[mount_path] = {
        inodes = {},
        dentries = {},
    }
    return Superblock.create("", mount_path, 1, self)
end