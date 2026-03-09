write(1, "Hello, Hecate!\n")
local ok, pid = pcall(spawn, "/bin/sh.lua", {})
wait(pid)
