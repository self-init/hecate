local CharacterDevice = Device:new("char")

function CharacterDevice:new(name, type, bus)
    local device = Device:new("char", name, type, bus)
    setmetatable(device, self)
    self.__index = self
    return device
end

function CharacterDevice:read_bytes(bytes)
    if self.driver == nil then
        error("Error: " .. self.name .. " read_bytes: No driver is associated with this device.")
    end
    return self.driver:read_bytes(self, bytes)
end

function CharacterDevice:write_bytes(bytes)
    if self.driver == nil then
        error("Error: " .. self.name .. " write_bytes: No driver is associated with this device.")
    end
    return self.driver:write_bytes(self, bytes)
end

function CharacterDevice:get_available_bytes()
    if self.driver == nil then
        error("Error: " .. self.name .. " get_available_bytes: No driver is associated with this device.")
    end
    return self.driver:get_available_bytes(self)
end
