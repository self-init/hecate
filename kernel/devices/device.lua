-- Base class for devices

local Device = {}

function Device:new(name, type, bus)
    local device = {
        name = name,
        type = type,
        bus = bus,
        dev_type = nil,
        driver = nil,
    }
    setmetatable(device, self)
    self.__index = self

    return device
end

function Device:open(inode, mode)
    if self.driver == nil then
        error("Error: " .. self.name .. " open: No driver is associated with this device.")
    end
    self.driver:open(self, inode, mode)
end

function Device:read_bytes(inode, bytes)
    if self.driver == nil then
        error("Error: " .. self.name .. " read_bytes: No driver is associated with this device.")
    end
    self.driver:read_bytes(self, inode, bytes)
end

function Device:write_bytes(inode, bytes)
    if self.driver == nil then
        error("Error: " .. self.name .. " write_bytes: No driver is associated with this device.")
    end
    self.driver:write_bytes(self, inode, bytes)
end

function Device:get_available_bytes(inode, bytes)
    if self.driver == nil then
        error("Error: " .. self.name .. " get_available_bytes: No driver is associated with this device.")
    end
    self.driver:get_available_bytes(self, inode, bytes)
end

function Device:close(inode)
    if self.driver == nil then
        error("Error: " .. self.name .. " close: No driver is associated with this device.")
    end
    self.driver:close(self, inode)
end
