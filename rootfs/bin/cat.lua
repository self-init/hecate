if #argv < 2 then
	write(2, "usage: cat <file>...\n")
	exit(1)
end

local function cat(path)
	local fd = open(path, 0)
	repeat
		chunk = read(fd, 512)
		write(1, chunk)
	until chunk == ""
	close(fd)
end

local status = 0
for i = 2, #argv do
	local ok, err = pcall(cat, argv[i])
	if not ok then
		write(2, "cat: " .. tostring(err) .. "\n")
		status = 1
	end
end
exit(status)
