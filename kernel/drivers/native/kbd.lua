local BaseChrDev = require("drivers.basechrdev")

---@class Kbd: BaseChrDev
local Kbd = BaseChrDev:new()

function Kbd:push_event(event)
    table.insert(self.queue, event)
end

function Kbd:read_file(inode, offset, length)
	return table.remove(self.queue, 1)
end

return Kbd
