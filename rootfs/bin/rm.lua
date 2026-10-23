--TODO: Improve when stat syscall is added

if #argv < 2 then
	write(2, "usage: rm <file>...\n")
	exit(1)
end

local status = 0
for i = 2, #argv do
	local ok, err = pcall(unlink, argv[i])
	if not ok then
		write(2, "rm: " .. tostring(err) .. "\n")
		status = 1
	end
end
exit(status)
