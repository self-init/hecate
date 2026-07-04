---@class Mount
---@field driver          Driver
---@field parent          Mount?   nil for the root mount
---@field mountpoint_inode Inode?  inode in the parent filesystem where this is mounted (nil for root)
---@field root_inode      Inode    root inode of this filesystem
---@field children        table<integer, Mount>  inode_id → child Mount
local Mount = {}

---@param driver Driver
---@param parent Mount?
---@param mountpoint_inode Inode?
---@param root_inode Inode
---@return Mount
function Mount:new(driver, parent, mountpoint_inode, root_inode)
    local m = {
        driver             = driver,
        parent             = parent,
        mountpoint_inode   = mountpoint_inode,
        root_inode         = root_inode,
        children           = {},
    }
    setmetatable(m, self)
    self.__index = self
    return m
end

return Mount
