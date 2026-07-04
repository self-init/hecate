local Kbd = require("drivers.cc.kbd")
local CCTty = require("drivers.cc.tty")
local Null = require("drivers.agnostic.null")
local InodeModeFlags = require("vfs.inode.modeflags")

---Map CC key scan codes to the control characters the TTY line discipline expects.
---"char" events never fire for these keys, so they must be injected via "key".
---@type table<unknown, string>
local KEY_TO_CHAR = {
	[keys.enter]       = "\n",
	[keys.numPadEnter] = "\n",
	[keys.backspace]   = "\8", -- byte 8 = VERASE default
}

---@class CCArch: Arch
---@field kbd_queue table
---@field event_refcount table<string, integer> {event = ref_count}}
local CCArch = {}

---Creates a new arch instance for ComputerCraft
---@return CCArch
function CCArch:new()
	local ccarch = {
		kbd_queue = {},
		events_listeners = {}
	}
	setmetatable(ccarch, self)
	self.__index = self

	return ccarch
end

---Creates the ComputerCraft architecture and initial devices.
---Also creates a timer for CC specific functionality.
---@param kernel Kernel
function CCArch:init(kernel)
	self._timer_id = os.startTimer(0.05)
	self._kernel = kernel

	-- Create mountpoint files in devfs before mounting char drivers.
	-- Level 3 VFS requires a real inode to exist at each mountpoint path.
	local devfs_mount, devfs_root = kernel.vfs:namei("/dev", nil, nil, nil)
	devfs_mount.driver:create_file(devfs_root, "tty",  InodeModeFlags.TYPE_CHR)
	devfs_mount.driver:create_file(devfs_root, "kbd",  InodeModeFlags.TYPE_CHR)
	devfs_mount.driver:create_file(devfs_root, "null", InodeModeFlags.TYPE_CHR)

	self.tty = CCTty:new(self)
	kernel.vfs:mount(self.tty,       "/dev/tty")
	kernel.vfs:mount(Kbd:new(self),  "/dev/kbd")
	kernel.vfs:mount(Null:new(self), "/dev/null")
end

---Performs some step and upkeep work for the kernel, called every scheduler step.
---Also handles sig_kill temporarily
---@return nil
function CCArch:step()
	local event, p1, p2 = os.pullEventRaw()
	if event == "timer" and p1 == self._timer_id then
		self._timer_id = os.startTimer(0.05)
	elseif event == "char" then
		self.tty:push_input(p1)
	elseif event == "key" then
		table.insert(self.kbd_queue, { event = "key_down", key = p1 })
		local ch = KEY_TO_CHAR[p1]
		if ch then self.tty:push_input(ch) end
	elseif event == "key_up" then
		table.insert(self.kbd_queue, { event = "key_up", key = p1 })
	elseif event == "terminate" then
		-- Kill the foreground process (highest-PID non-init process).
		-- If only init is running, ignore the event.
		local target_pid, target_proc
		for pid, proc in pairs(self._kernel.procman.processes) do
			if pid ~= 0 and not proc.dead then
				if target_pid == nil or pid > target_pid then
					target_pid = pid
					target_proc = proc
				end
			end
		end
		if target_proc then
			target_proc.dead      = true
			target_proc.exit_code = -1
		else
			os.shutdown()
		end
	else
		return nil
	end
end

return CCArch
