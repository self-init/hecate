local BaseFS = require("drivers.common.basefs")

---@class RamFS: BaseFS
---@field data table<integer, string>
local RamFS = BaseFS:new()

---@param arch Arch
---@return RamFS
function RamFS:new(arch)
    local fs = BaseFS.new(self, arch)
    fs.data = {}
    return fs
end


---@param inode Inode
---@param offset integer
---@param length integer
function RamFS:read_file(inode, offset, length)
    local contents = self.data[inode.id] or ""
    return contents:sub(offset + 1, offset + length)
end

---@param inode Inode
---@param offset integer
---@param data any
function RamFS:write_file(inode, offset, data)
    local contents = self.data[inode.id] or ""
    local prefix = contents:sub(1, offset)
    if #prefix < offset then
        prefix = prefix .. string.rep("\0", offset - #prefix)
    end
    local suffix = contents:sub(offset + #data + 1)
    self.data[inode.id] = prefix .. data .. suffix
    inode.size = #self.data[inode.id]
    return #data
end

---@param inode Inode
function RamFS:_free_inode(inode)
    BaseFS._free_inode(self, inode)
    self.data[inode.id] = nil
end

return RamFS
