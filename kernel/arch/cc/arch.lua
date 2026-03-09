local Kbd = require("drivers.cc.kbd")
local CCTty = require("drivers.cc.tty")

-- Map CC key scan codes to the control characters the TTY line discipline expects.
-- "char" events never fire for these keys, so they must be injected via "key".
local KEY_TO_CHAR = {
	[keys.enter]       = "\n",
	[keys.numPadEnter] = "\n",
	[keys.backspace]   = "\8", -- byte 8 = VERASE default
}

---@class CCArch: Arch
---@field kbd_queue table
---@field event_refcount table<string, integer> {event = ref_count}}
local CCArch = {}

function CCArch:new()
	local ccarch = {
		kbd_queue = {},
		events_listeners = {}
	}
	setmetatable(ccarch, self)
	self.__index = self

	return ccarch
end

function CCArch:init(kernel)
	self._timer_id = os.startTimer(0.05)
	self._kernel = kernel

	self.tty = CCTty:new(self)
	kernel.vfs:mount(self.tty, "/dev/tty")
	kernel.vfs:mount(Kbd:new(self), "/dev/kbd")
end

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
