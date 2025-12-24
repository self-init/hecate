
local mount = {}

function mount.new(device, mount_path)
    return {
        mnt = mount_path,
        mnt_root = device
    }
end
