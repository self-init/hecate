local function print(str)
	write("/dev/tty", 0, str .. "\n")
end

print("Hello World!")
print("Root directory contents: ")
for _, file in ipairs(read_dir("/")) do
	print(file)
end
while true do
	local event = read("/dev/kbd", 0, 0)
 	if event then
  		write("/dev/tty", 0, tostring(event.key) .. "\n")
    end
end
