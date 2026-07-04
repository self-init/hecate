local BaseChrDev = require("drivers.common.basechrdev")

---@class Null: BaseChrDev
local Null = BaseChrDev:new()

function Null:read_file(inode, offset, length)
    return ""
end

function Null:write_file(inode, offset, data)
    return #data
end

return Null
