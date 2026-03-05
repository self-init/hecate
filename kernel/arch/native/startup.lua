local Kernel = require("kernel")
local NativeArch = require("arch.native.arch")

local function main()
    local kernel = Kernel:new(NativeArch:new())
    kernel:start()
end

main()
