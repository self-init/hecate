---@class GenericArch: Arch
local NativeArch = {}

function NativeArch:new()
    local genarch = {

    }
    setmetatable(genarch, self)
    self.__index = self

    return genarch
end

function NativeArch:init(kernel)

end

function NativeArch:step()
    return nil
end

function NativeArch:tty_write(data)
	io.write(data)
end

return NativeArch
