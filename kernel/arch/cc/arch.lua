---@class CCArch: Arch
CCArch = {}

function CCArch:new()
    local ccarch = {

    }
    setmetatable(ccarch, self)
    self.__index = self

    return ccarch
end

function CCArch:read_key()
    local event, key, held = os.pullEvent()
	if event == "key" then
        return { type = "key_down", key = key, held = held }
	elseif event == "key_up"  then
		return { type = "key_up", key = key }
	end
end


function CCArch:init(kernel)

end
