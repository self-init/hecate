local BaseChrDev = require("drivers.common.basechrdev")

---@class Tty: BaseChrDev
local Tty = BaseChrDev:new()

function Tty:write_file(inode, offset, data)
	self.arch:tty_write(data)
end

return Tty
