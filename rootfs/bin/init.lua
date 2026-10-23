write(1, "Hello, Hecate!\n")
repeat
	local ok, pid = pcall(spawn, "/bin/sh.lua", {})
	if not ok then break end
	local code = wait(pid)
until code ~= -1
