local Driver = {}

function Driver:new(name, match_table)
    local device = {
        name = name,
        match_table = match_table
    }
    setmetatable(device, self)
    self.__index = self

    return device
end
