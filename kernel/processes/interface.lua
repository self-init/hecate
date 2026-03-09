local FileDescriptor = require("vfs.fd")
local Bitwise = require("common.bitwise")
local btest = Bitwise.btest

local ProcessInterface = {}

---@param process Process
---@return ProcessInterface
function ProcessInterface.new(process)
	---@class ProcessInterface
	local process_interface = {}
	local vfs = process.kernel.vfs
	local procman = process.kernel.procman

	-- Replace the current process image with a new executable.
	-- exec() does not return; the new image starts on the next scheduler step.
	function process_interface.exec(path)
		process:exec(path)
		coroutine.yield() -- suspend old coroutine; scheduler resumes the new one
	end

	-- Create a new child process running the given executable.
	-- Returns the child's PID.
	function process_interface.spawn(path, argv)
		local Process = require("processes.process")
		local child = Process:new(process.kernel, path, argv)
		child.ppid = process.pid
		child.current_directory = process.current_directory
		procman:add_process(child)
		return child.pid
	end

	-- Open a file; returns an fd number.
	function process_interface.open(path, flags)
		return process:open_fd(path, flags)
	end

	-- Close an fd.
	function process_interface.close(fd)
		process:close_fd(fd)
	end

	-- Read up to length bytes from fd at the current position.
	function process_interface.read(fd, length)
		local f = process.file_descriptors[fd]
		assert(f, "EBADF: invalid file descriptor " .. tostring(fd))
		if not btest(f.flags, FileDescriptor.O_NONBLOCK) then
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
	function process_interface.write(fd, data)
		local f = process.file_descriptors[fd]
		assert(f, "EBADF: invalid file descriptor " .. tostring(fd))
		return f:write(data)
	end

	-- Perform a device-specific control operation on fd.
	function process_interface.ioctl(fd, request, arg)
		local f = process.file_descriptors[fd]
		assert(f, "EBADF: invalid file descriptor " .. tostring(fd))
		return f:ioctl(request, arg)
	end

	-- Reposition the fd's file offset.
	function process_interface.seek(fd, offset, whence)
		local f = process.file_descriptors[fd]
		assert(f, "EBADF: invalid file descriptor " .. tostring(fd))
		return f:seek(offset, whence)
	end

	function process_interface.read_dir(path)
		return vfs:read_dir(process, path)
	end

	function process_interface.getcwd()
		return process.current_directory
	end

	function process_interface.chdir(path)
		process:chdir(path)
	end

	function process_interface.exit(code)
		process.dead = true
		process.exit_code = code or 0
		coroutine.yield()
	end

	function process_interface.wait(pid)
		local proc = procman.processes[pid]
		while proc and not proc.dead do
			coroutine.yield()
			proc = procman.processes[pid]
		end
		return proc and proc.exit_code
	end

	return process_interface
end

return ProcessInterface
