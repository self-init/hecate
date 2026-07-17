local FileDescriptor = require("vfs.fd")
local FileDescriptorOpenFlags = require("vfs.fd.openflags")
local Bitwise = require("common.bitwise")
local btest = Bitwise.btest
local Error = require("common.error")

local ProcessInterface = {}

---Creates a new ProcessInterface instance for the given process
---@param process Process
---@return ProcessInterface
function ProcessInterface.new(process)
    ---The process interface class allows a process to interact with the kernel
    ---while preventing direct access to kernel memory.
	---@class ProcessInterface
	local process_interface = {}
	local vfs = process.kernel.vfs
	local procman = process.kernel.procman
	local loaded = {}  -- per-process module cache

	-- Replace the current process image with a new executable.
    -- exec() does not return; the new image starts on the next scheduler step.
    ---@param path string
	function process_interface.exec(path)
		process:exec(path)
		coroutine.yield() -- suspend old coroutine; scheduler resumes the new one
	end

	-- Create a new child process running the given executable.
    -- Returns the child's PID.
    ---@param path string
    ---@param argv table
    ---@return integer
	function process_interface.spawn(path, argv)
		local Process = require("processes.process")
		local child = Process:new(process.kernel, path, argv)
		child.ppid              = process.pid
		child.current_directory = process.current_directory
		child.cwd_mount         = process.cwd_mount
        child.cwd_inode         = process.cwd_inode
        child.fds:inherit(process.fds)
		procman:add_process(child)
		return child.pid
	end

    -- Open a file; returns an fd number.
    ---@param path string
    ---@param flags any
    ---@return integer
	function process_interface.open(path, flags)
		return process:open_fd(path, flags)
	end

    -- Close an fd.
	---@param fd integer
	function process_interface.close(fd)
		process:close_fd(fd)
	end

    -- Read up to length bytes from fd at the current position.
	---@param fd integer
	---@param length integer
	---@return any
	function process_interface.read(fd, length)
		local f = process.fds:get(fd)
		if not f then Error.throw(Error.EBADF, "invalid file descriptor " .. tostring(fd)) end
		if not btest(f.flags, FileDescriptorOpenFlags.O_NONBLOCK) then
			local data
			while data == nil do
				coroutine.yield()
				data = f:read(length)
			end
			return data
		else
			return f:read(length)
		end
	end

    -- Write data to fd at the current position.
    ---@param fd integer
    ---@param data any
    ---@return integer
	function process_interface.write(fd, data)
		local f = process.fds:get(fd)
		if not f then Error.throw(Error.EBADF, "invalid file descriptor " .. tostring(fd)) end
		return f:write(data)
	end

    -- Perform a device-specific control operation on fd.
	---@param fd integer
	---@param request any
	---@param arg any
	---@return any
	function process_interface.ioctl(fd, request, arg)
		local f = process.fds:get(fd)
		if not f then Error.throw(Error.EBADF, "invalid file descriptor " .. tostring(fd)) end
		return f:ioctl(request, arg)
	end

    -- Reposition the fd's file offset.
    ---@param fd integer
    ---@param offset integer
    ---@param whence any
    ---@return integer
	function process_interface.seek(fd, offset, whence)
		local f = process.fds:get(fd)
		if not f then Error.throw(Error.EBADF, "invalid file descriptor " .. tostring(fd)) end
		return f:seek(offset, whence)
	end

	-- Read directory entries from a directory fd opened with O_DIRECTORY.
    -- Returns a table of entry name strings, always including "." and "..".
    ---@param fd any
    ---@return table<integer, string>
	function process_interface.getdents(fd)
		local f = process.fds:get(fd)
		if not f then Error.throw(Error.EBADF, "invalid file descriptor " .. tostring(fd)) end
		if not btest(f.flags, FileDescriptorOpenFlags.O_DIRECTORY) then
			Error.throw(Error.ENOTDIR, "fd " .. tostring(fd) .. " is not a directory fd")
		end
		local entries = f.driver:read_dir(f.inode)
		local entry_set = {}
		for _, name in ipairs(entries) do entry_set[name] = true end
		if not entry_set["."]  then table.insert(entries, ".")  end
		if not entry_set[".."] then table.insert(entries, "..") end
		return entries
	end

	-- Open a file relative to a directory fd, avoiding TOCTOU races.
    -- dirfd must be an fd opened with O_DIRECTORY.
	---@param dirfd any
	---@param path string
	---@param flags any
	---@return integer
    function process_interface.openat(dirfd, path, flags)
        local dir_f = process.fds:get(dirfd)
        if not dir_f then Error.throw(Error.EBADF, "invalid file descriptor " .. tostring(dirfd)) end
        if not btest(dir_f.flags, FileDescriptorOpenFlags.O_DIRECTORY) then
            Error.throw(Error.ENOTDIR, "fd " .. tostring(dirfd) .. " is not a directory fd")
        end
        return process:open_fd(path, flags, dir_f.mount, dir_f.inode)
    end

    ---@param path string
	function process_interface.unlink(path)
		vfs:unlink(process, path)
	end

	---@param path string
	function process_interface.mkdir(path)
		vfs:mkdir(process, path)
	end

	---@param path string
	function process_interface.rmdir(path)
		vfs:rmdir(process, path)
	end

	---@param path string
	function process_interface.read_dir(path)
		return vfs:read_dir(process, path)
	end

	function process_interface.getcwd()
		return process.current_directory
	end

	---@param path string
    function process_interface.chdir(path)
        process:chdir(path)
    end

    ---@param code integer
	function process_interface.exit(code)
		process.dead = true
		process.exit_code = code or 0
		coroutine.yield()
	end

	---@param pid integer
	function process_interface.wait(pid)
		local proc = procman:get_process(pid)
		while proc and not proc.dead do
			coroutine.yield()
			proc = procman:get_process(pid)
		end
		return proc and proc.exit_code
	end

	-- Load a Lua module from /lib/ and execute it in the process's environment.
    -- Follows the same mod.name -> /lib/mod/name.lua resolution as the bundler.
	function process_interface.require(mod_name)
		if loaded[mod_name] then
			return loaded[mod_name]
		end

		local base = "/lib/" .. mod_name:gsub("%.", "/")
		local candidates = { base .. ".lua", base .. "/init.lua" }

		local code, found_path
		for _, path in ipairs(candidates) do
			local mount, inode
			local ok = pcall(function()
				mount, inode = vfs:namei(path, nil, nil, nil)
			end)
			if ok and inode then
				code = mount.driver:read_file(inode, 0, inode.size)
				found_path = path
				break
			end
		end

		if not code then
			error("module '" .. mod_name .. "' not found")
		end

		local chunk, err = load(code, "@" .. found_path, "t", process.env)
		if not chunk then
			error("error loading module '" .. mod_name .. "': " .. err)
		end

		local result = chunk()
		loaded[mod_name] = result ~= nil and result or true
		return loaded[mod_name]
	end

	return process_interface
end

return ProcessInterface
