local BaseChrDev = require("drivers.basechrdev")

---@class Tty: BaseChrDev
local Tty = BaseChrDev:new()

function Tty:write(inode, offset, data)
	self.arch:tty_write(data)
end

return Tty
