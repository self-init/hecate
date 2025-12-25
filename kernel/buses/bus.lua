-- Base class for busses

local Bus = {}

function Bus:new(bus_name)
    local bus = {
        name = bus_name or "",
        devices = {},
        drivers = {},
    }
    setmetatable(bus, self)
    self.__index = self

    return bus
end

-- Check if a driver supports a device. Returns a boolean.
function Bus:match(device, driver)
    if TableTools.find(driver.match_table, device.type) then
        return true
    end
    return false
end

-- This function should scan for new devices and register any new ones using the device_register() function.
function Bus:scan_devices()
    error("Error: scan_devices() is not implemented on this Bus object.")
end

-- Register a new device with the bus
function Bus:device_register(device)
    table.insert(self.devices, device)
    -- Iterate over drivers and if one matches, set it as the device's driver
    for _, driver in ipairs(self.drivers) do
        if self:match(device, driver) then
            device.driver = driver
            return
        end
    end
end

-- Register a new driver with the bus
function Bus:driver_register(driver)
    table.insert(self.drivers, driver)
    -- Iterate over devices that don't have a driver, and if they match, set it as that device's driver
    for _, device in ipairs(self.devices) do
        if device.driver ~= nil then
            if self:match(device, driver) then
                device.driver = driver
            end
        end
    end
end
