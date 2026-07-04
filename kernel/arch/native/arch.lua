local NativeTty = require("drivers.native.tty")
local Kbd = require("drivers.native.kbd")
local Null = require("drivers.agnostic.null")
local InodeModeFlags = require("vfs.inode.modeflags")


---@class NativeArch: Arch
---@field tty NativeTty
local NativeArch = {}

function NativeArch:new()
    local genarch = {}
    setmetatable(genarch, self)
    self.__index = self
    return genarch
end

function NativeArch:init(kernel)
	self._kernel = kernel

    -- min 0 time 1: io.read(1) returns after at most 100ms with no data
    os.execute("stty raw -echo min 0 time 1 2>/dev/null")


	-- Create mountpoint files in devfs before mounting char drivers.
	-- Level 3 VFS requires a real inode to exist at each mountpoint path.
	local devfs_mount, devfs_root = kernel.vfs:namei("/dev", nil, nil, nil)
	devfs_mount.driver:create_file(devfs_root, "tty",  InodeModeFlags.TYPE_CHR)
	devfs_mount.driver:create_file(devfs_root, "kbd",  InodeModeFlags.TYPE_CHR)
	devfs_mount.driver:create_file(devfs_root, "null", InodeModeFlags.TYPE_CHR)

    self.tty = NativeTty:new(self)
    kernel.vfs:mount(self.tty,      "/dev/tty")
	kernel.vfs:mount(Kbd:new(self), "/dev/kbd")
	kernel.vfs:mount(Null:new(self), "/dev/null")
end

function NativeArch:step()
    local ch = io.read(1)
    if not ch or #ch == 0 then return end
    -- Ctrl+C: restore terminal and abort
    if ch == "\3" then
        os.execute("stty sane 2>/dev/null")
        os.exit(1)
    end
    -- Most Linux terminals send DEL (127) for backspace; remap to ^H (8)
    if ch:byte() == 127 then ch = "\8" end
    self.tty:push_input(ch)
end

return NativeArch
