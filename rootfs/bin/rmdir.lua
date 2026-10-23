--TODO: Improve when stat syscall is added

if #argv < 2 then
	write(2, "usage: rmdir <directory>...\n")
	exit(1)
end

local status = 0
for i = 2, #argv do
	local ok, res, err = pcall(rmdir, argv[i])
	if not ok then
		err = res
	end
	if not ok or not res then
		write(2, "rmdir: " .. tostring(err) .. "\n")
		status = 1
	end
end
exit(status)
