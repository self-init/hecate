write(1, "Hello, Hecate!\n")
local ok, pid = pcall(spawn, "/bin/sh.lua", {})
if ok then wait(pid) end
