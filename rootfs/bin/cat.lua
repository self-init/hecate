if #argv < 2 then
	write(2, "usage: cat <file>...\n")
	exit(1)
end

local function cat(path)
	local fd = open(path, 0)
	local chunk = read(fd, 512)
	while chunk ~= "" do
		write(1, chunk)
		chunk = read(fd, 512)
	end
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
