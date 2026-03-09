local function print(str)
	write(1, str)
end

local function println(str)
	write(1, str .. "\n")
end

println("Hello, Hecate!")

local internal_commands = {
	cd = function(tokens)
		if #tokens < 2 then

		else
			chdir(tokens[2])
		end
	end
}

local function internal_command(command, tokens)
	internal_commands[command](tokens)
end

local function external_command(command, tokens)
	local path = command:find("/") and command or "/bin/" .. command

	-- Build argv: resolve the path as argv[1], rest follow
	local argv = { path }
	for i = 2, #tokens do
		table.insert(argv, tokens[i])
	end

	local ok, pid = pcall(spawn, path, argv)
	if not ok and not path:find("%.lua$") then
		argv[1] = path .. ".lua"
		ok, pid = pcall(spawn, path .. ".lua", argv)
	end

	if not ok then
		write(2, "hecate: " .. command .. ": command not found\n")
	else
		wait(pid)
	end
end

while true do
	print("$ ")
	local line = read(0, 256)
	line = line:gsub("\n$", "")

	if line == "exit" then
		exit(0)
	elseif line ~= "" then
		-- Tokenize
		local tokens = {}
		for token in line:gmatch("%S+") do
			table.insert(tokens, token)
		end

        local cmd = tokens[1]
		if internal_commands[cmd] then
			internal_command(cmd, tokens)
		else
			external_command(cmd, tokens)
		end
	end
end
