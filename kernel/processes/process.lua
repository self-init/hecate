local ProcessInterface        = require("processes.interface")
local Credentials             = require("processes.credentials")
local FDTable                 = require("processes.fdtable")
local Paths                   = require("common.paths")
local Bitwise                 = require("common.bitwise")
local Inode                   = require("vfs.inode")
local InodeModeFlags          = require("vfs.inode.modeflags")
local FileDescriptor          = require("vfs.fd")
local FileDescriptorOpenFlags = require("vfs.fd.openflags")
local Error                   = require("common.error")
local band                    = Bitwise.band

---@class Process
---@field pid               number
---@field ppid              number
---@field cred              Credentials
---@field capabilities      number
---@field fds               FDTable
---@field current_directory string
---@field cwd_mount         Mount   authoritative current-directory mount
---@field cwd_inode         Inode   authoritative current-directory inode
---@field argv              string[]
---@field envp              string[]
---@field dead              boolean
---@field exit_code         number
---@field coroutine         thread
---@field kernel            Kernel
---@field env               table
local Process                 = {
	-- [ Capabilities ]
	CAP_CHOWN = nil,        --
	CAP_DAC_OVERRIDE = nil, --
	CAP_DAC_READ_SEARCH = nil, --
	CAP_KILL = nil,         -- Kill arbitrary processes
	CAP_MKNOD = nil,        -- Create special files
	CAP_NET_ADMIN = nil,    --
	CAP_SETGID = nil,       --
	CAP_SETUID = nil,       --
	CAP_SYS_ADMIN = nil,    --
	CAP_SYS_BOOT = nil,     --
	CAP_SYSLOG = nil,       --
}

function Process:new(kernel, path, argv)
	local proc = {
		pid               = 0,
		ppid              = 0,
		cred              = Credentials.create(),
		fds               = FDTable:new(),
		current_directory = "/",
		cwd_mount         = kernel.vfs.root_mount,
		cwd_inode         = kernel.vfs.root_mount.root_inode,
		argv              = argv or {},
		envp              = {},
		dead              = false,
		exit_code         = nil,
		coroutine         = nil,
		kernel            = kernel
	}
	setmetatable(proc, self)
	self.__index = self

	proc:_open_tty_fds()
	proc:exec(path)
	return proc
end

-- Pre-open /dev/tty as stdin(0), stdout(1), stderr(2).
function Process:_open_tty_fds()
	local mount, inode = self.kernel.vfs:namei("/dev/tty", nil, nil, nil)
	for n = 0, 2 do
		self.fds:set(n, FileDescriptor:new(mount, inode, "/dev/tty", FileDescriptorOpenFlags.O_RDWR))
	end
end

-- Open a file or directory and return its fd number.
-- base_mount/base_inode override cwd_mount/cwd_inode for path resolution (used by openat).
---@param path       string
---@param flags      integer  O_RDONLY | O_WRONLY | O_RDWR | O_CREAT | O_TRUNC | O_APPEND | O_DIRECTORY | O_CLOEXEC
---@param base_mount Mount?
---@param base_inode Inode?
---@return integer  fd number
function Process:open_fd(path, flags, base_mount, base_inode)
	local vfs       = self.kernel.vfs
	local cwd_mount = base_mount or self.cwd_mount
	local cwd_inode = base_inode or self.cwd_inode
	local mount, inode = vfs:namei(path, self.cred, cwd_mount, cwd_inode)

	if inode == nil then
		if band(flags, FileDescriptorOpenFlags.O_CREAT) ~= 0 then
			local name        = path:match("[^/]+$") or path
			local parent_path = path:match("^(.+)/[^/]+$") or (path:sub(1,1) == "/" and "/" or ".")
			local parent_mount, parent_inode = vfs:namei(parent_path, self.cred, cwd_mount, cwd_inode)
			if parent_inode == nil then
				Error.throw(Error.ENOENT, path)
			end
			vfs:check_inode_perm(self.cred, parent_inode, InodeModeFlags.MASK_WRITE, path)
			vfs:check_inode_perm(self.cred, parent_inode, InodeModeFlags.MASK_EXEC, path)
			inode = parent_mount.driver:create_file(parent_inode, name, InodeModeFlags.TYPE_REG)
			mount = parent_mount
		else
			Error.throw(Error.ENOENT, path)
		end
	end

	local is_dir = Inode.get_file_type(inode, InodeModeFlags.TYPE_DIR)
	if is_dir and band(flags, FileDescriptorOpenFlags.O_DIRECTORY) == 0 then
		Error.throw(Error.EISDIR, path)
	end
	if not is_dir and band(flags, FileDescriptorOpenFlags.O_DIRECTORY) ~= 0 then
		Error.throw(Error.ENOTDIR, path)
	end

	-- Extract the access mode from the low two bits, ignoring other flags (O_CLOEXEC etc.)
	local accmode = band(flags, 0x0003)
	if accmode ~= FileDescriptorOpenFlags.O_WRONLY then
		vfs:check_inode_perm(self.cred, inode, InodeModeFlags.MASK_READ, path)
	end
	if accmode ~= FileDescriptorOpenFlags.O_RDONLY then
		vfs:check_inode_perm(self.cred, inode, InodeModeFlags.MASK_WRITE, path)
	end

	if band(flags, FileDescriptorOpenFlags.O_TRUNC) ~= 0 then
		mount.driver:write_file(inode, 0, "")
		inode.size = 0
	end

	return self.fds:insert(FileDescriptor:new(mount, inode, path, flags))
end

-- Close an open file descriptor.
---@param n integer
function Process:close_fd(n)
	self.fds:close(n)
end

-- Builds the sandboxed global environment for a process.
-- Exposes safe Lua builtins and the ProcessInterface syscalls.
function Process:make_env()
	local env = {
		-- Safe Lua standard library
		math         = math,
		string       = string,
		table        = table,
		ipairs       = ipairs,
		pairs        = pairs,
		next         = next,
		type         = type,
		tostring     = tostring,
		tonumber     = tonumber,
		select       = select,
		error        = error,
		assert       = assert,
		pcall        = pcall,
		xpcall       = xpcall,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget       = rawget,
		rawset       = rawset,
		rawequal     = rawequal,
		rawlen       = rawlen,
		bitwise      = Bitwise,
	}

	-- File descriptor open flags and seek constants
	for k, v in pairs(FileDescriptorOpenFlags) do
		env[k] = v
	end
	env.argv  = self.argv
	self.env  = env

	-- Merge ProcessInterface functions in as globals
	for k, v in pairs(ProcessInterface.new(self)) do
		env[k] = v
	end

	env._ENV = env
	return env
end

function Process:exec(path)
	local vfs           = self.kernel.vfs
	local mount, inode  = vfs:namei(path, self.cred, self.cwd_mount, self.cwd_inode)

	if inode == nil then
		Error.throw(Error.ENOENT, path)
	end

	if not Inode.get_file_type(inode, InodeModeFlags.TYPE_REG) then
		Error.throw(Error.ENOEXEC, path)
	end

	vfs:check_inode_perm(self.cred, inode, InodeModeFlags.MASK_EXEC, path)

	-- Read file as the kernel, bypassing the process's read permission check.
	local code = mount.driver:read_file(inode, 0, inode.size)

	local chunk, err = load(code, "@" .. path, "t", self:make_env())
	if not chunk then
		Error.throw(Error.ENOEXEC, path .. ": " .. err)
	end

	self.coroutine = coroutine.create(chunk)
	self.fds:close_cloexec()
end

function Process:kill()

end

function Process:chdir(path)
	local vfs          = self.kernel.vfs
	local mount, inode = vfs:namei(path, self.cred, self.cwd_mount, self.cwd_inode)

	if inode == nil then
		Error.throw(Error.ENOENT, path)
	end

	if not Inode.get_file_type(inode, InodeModeFlags.TYPE_DIR) then
		Error.throw(Error.ENOTDIR, path)
	end

	vfs:check_inode_perm(self.cred, inode, InodeModeFlags.MASK_EXEC, path)

	self.cwd_mount         = mount
	self.cwd_inode         = inode
	self.current_directory = Paths.resolve(path, self.current_directory)
end

return Process
