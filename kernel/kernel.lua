---@class Kernel
---@field arch Arch
---@field vfs Vfs
---@field procman ProcessManager
Kernel = {}

function Kernel:new(arch)
	local kernel = {
        arch = arch,
        vfs = Vfs:new(),
        procman = ProcessManager:new(),
	}

	setmetatable(kernel, self)
	self.__index = self

	return kernel
end

function Kernel:start()
    self.arch:init(self)

    self.vfs:mount(RamFS:new(self.arch), "/dev")
    self.vfs:mount(Kbd:new(self.arch), "/dev/kbd")
    self.vfs:mount(Tty:new(self.arch), "/dev/tty")

    while true do
		self.procman:step()
	end
end
