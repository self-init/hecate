local function main()
    term.clear()
    term.setCursorPos(1,1)
    local kernel = Kernel:new(CCArch:new())
    kernel:start()
end

main()
