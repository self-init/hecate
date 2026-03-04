local Kernel = require("kernel")
local CCArch = require("arch.cc.arch")

local function main()
	---@diagnostic disable-next-line: undefined-global
    term.clear()
    ---@diagnostic disable-next-line: undefined-global
    term.setCursorPos(1,1)
    local kernel = Kernel:new(CCArch:new())
    kernel:start()
end

main()
