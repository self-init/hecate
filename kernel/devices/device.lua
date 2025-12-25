-- Base class for devices

local Device = {}

function Device:new(name, type, bus)
    local device = {
        name = name,
        type = type,
        bus = bus,
        driver = nil,
    }
    setmetatable(device, self)
    self.__index = self

    return device
end
