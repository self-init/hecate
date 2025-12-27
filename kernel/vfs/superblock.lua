local Superblock = {}

function Superblock.create(device, mount_path, root_inode)
    return {
        mnt = mount_path,
        device = device,
        root_inode = root_inode
    }
end
