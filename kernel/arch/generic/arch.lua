GenericArch = {}

function GenericArch:new()
    local genarch = {

    }
    setmetatable(genarch, self)
    self.__index = self

    return genarch
end

function GenericArch:read_key()

end

function GenericArch:init(kernel)

end

function GenericArch:tty_write(data)
	io.write(data)
end
