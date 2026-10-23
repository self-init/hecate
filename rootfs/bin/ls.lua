local dir = argv[2] or "."
local ok, entries, err = pcall(read_dir, dir)
if not ok then err = entries; entries = nil end
if not entries then
	write(2, "ls: " .. tostring(err) .. "\n")
	exit(1)
end
for _, entry in ipairs(entries) do
	write(1, entry .. "\n")
end
