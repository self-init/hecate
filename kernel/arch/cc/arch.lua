local Kbd = require("drivers.cc.kbd")

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

	kernel.vfs:mount(Kbd:new(self), "/dev/kbd")
end

function CCArch:step()
	local event, p1, p2 = os.pullEventRaw()
	if event == "timer" and p1 == self._timer_id then
		self._timer_id = os.startTimer(0.05)
	elseif event == "key" then
		table.insert(self.kbd_queue, event)
	elseif event == "key_up" then
		table.insert(self.kbd_queue, event)
	elseif event == "terminate" then
		error("Terminated")
	else
		return nil
	end
end

function CCArch:tty_write(data)
	io.write(data)
end

return CCArch
