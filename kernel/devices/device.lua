-- Base class for devices
local Device = {}

function Device:new(dev_type, name, type, bus)
    local device = {
        name = name,
        type = type,
        bus = bus,
        dev_type = dev_type,
        driver = nil,
    }
    setmetatable(device, self)
    self.__index = self

    return device
end
