local function main()
    term.clear()
    term.setCursorPos(1,1)
    local kernel = Kernel.new(Kernel.ARCH_COMPUTERCRAFT)
    local ccbus = Bus:new("cc_bus")
    kernel:register_bus(ccbus)
    kernel:register_driver(ComputerCraftBus)
    kernel:start()
end

main()
