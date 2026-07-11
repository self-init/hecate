local Vfs = require("vfs.vfs")
local ProcessManager = require("processes.manager")
local RamFS = require("drivers.agnostic.ramfs")
local SerialFS = require("drivers.agnostic.serialfs")
local InodeModeFlags = require("vfs.inode.modeflags")
local Process = require("processes.process")

---@class Kernel
---@field arch Arch
---@field vfs Vfs
---@field procman ProcessManager
local Kernel = {}

function Kernel:new(arch)
	local kernel = {
		arch = arch,
		vfs = Vfs:create(),
		procman = ProcessManager:new(),
	}

	setmetatable(kernel, self)
	self.__index = self

	return kernel
end

function Kernel:start()
	-- Mount agnostic filesystems and devices
	local rootfs = SerialFS:new(self.arch, "rootfs.dat")
	self.vfs:mount(rootfs, "/")

	-- Ensure the /dev mountpoint directory exists in rootfs before mounting devfs.
	-- SerialFS restores from disk, so it may already be present.
	if not rootfs:get_inode("/dev") then
		rootfs:create_file(self.vfs.root_mount.root_inode, "dev", InodeModeFlags.TYPE_DIR)
	end

	local devfs = RamFS:new(self.arch)
	self.vfs:mount(devfs, "/dev")
	-- Mount devices
	self.arch:init(self)

	local init_process = Process:new(self, "/bin/init.lua")
	self.procman:add_process(init_process)
	while true do
		self.arch:step()
		self.procman:step()
		local init = self.procman.processes[1]
		if not init or init.dead then
			error("kernel panic: init (PID 1) died with exit code " .. tostring(init and init.exit_code))
		end
	end
end

return Kernel
