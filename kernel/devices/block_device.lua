local BlockDevice = Device:new("block")

function BlockDevice:new(name, type, bus)
    local device = Device:new("block", name, type, bus)
    setmetatable(device, self)
    self.__index = self

    return device
end

function BlockDevice:get_block_size()
    if self.driver == nil then
        error("Error: " .. self.name .. " get_block_size: No driver is associated with this device.")
    end
    return self.driver:get_block_size(self)
end

function BlockDevice:read_block(block)
    if self.driver == nil then
        error("Error: " .. self.name .. " read_block: No driver is associated with this device.")
    end
    return self.driver:read_block(self, block)
end

function BlockDevice:write_block(block, data)
    if self.driver == nil then
        error("Error: " .. self.name .. " write_block: No driver is associated with this device.")
    end
    return self.driver:write_block(self, block, data)
end
