local Kernel = require("kernel")
local NativeArch = require("arch.native.arch")

local function main()
    local kernel = Kernel:new(NativeArch:new())
    local ok, err = xpcall(kernel.start, debug.traceback, kernel)
    os.execute("stty sane 2>/dev/null")
    if not ok then
        io.write("\nkernel panic: " .. tostring(err) .. "\n")
    end
end

main()
