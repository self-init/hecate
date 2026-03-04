local Vfs = require("vfs.vfs")
local ProcessManager = require("processes.manager")
local Tty = require("drivers.tty")
local Kbd = require("drivers.kbd")
local RamFS = require("drivers.ramfs")
local Process = require("processes.process")
local Inode = require("vfs.inode")

---@class Kernel
---@field arch Arch
---@field vfs Vfs
---@field procman ProcessManager
local Kernel = {}

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

    ---@type RamFS
    local ramfs = RamFS:new(self.arch)
    local root_inode = self.vfs:mount(ramfs, "/")
    local init_file = ramfs:create_file(root_inode, "init.lua", Inode.TYPE_REG)
    ramfs:write(init_file, 0, 'print("Hello, world!")')

    self.vfs:mount(Kbd:new(self.arch), "/dev/kbd")
    self.vfs:mount(Tty:new(self.arch), "/dev/tty")

    local init_process = Process:new(self, "/init.lua")
    self.procman:add_process(init_process)
    while true do
        self.procman:step()
        local init = self.procman.processes[0]
        if not init or init.dead then
            error("kernel panic: init (PID 0) died with exit code " .. tostring(init and init.exit_code))
        end
    end
end

return Kernel
