local Superblock = {}

function Superblock.create(device, mount_path, root_inode, fs_driver)
    return {
        mnt = mount_path,
        device = device,
        root_inode = root_inode,
        fs_driver = fs_driver,
    }
end
