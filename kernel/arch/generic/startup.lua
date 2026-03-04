local Kernel = require("kernel")
local GenericArch = require("arch.generic.arch")

local function main()
    local kernel = Kernel:new(GenericArch:new())
    kernel:start()
end

main()
