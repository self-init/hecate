local ProcessInterface = require("processes.interface")
local Paths = require("common.paths")
local Bitwise = require("common.bitwise")
local Inode = require("vfs.inode")

---@class Process
---@field pid number
---@field ppid number
---@field ruid number
---@field euid number
---@field suid number
---@field rgid number
---@field egid number
---@field sgid number
---@field supplementary_groups number[]
---@field capabilities number
---@field file_descriptors table<number, FileDescriptor>
---@field current_directory string
---@field argv string[]
---@field envp string[]
---@field dead boolean
---@field exit_code number
---@field coroutine thread
---@field kernel Kernel
local Process = {
							   -- [ Capabilities ]
	CAP_CHOWN = nil,           --
	CAP_DAC_OVERRIDE = nil,    --
	CAP_DAC_READ_SEARCH = nil, --
	CAP_KILL = nil,            -- Kill arbitrary processes
	CAP_MKNOD = nil,           -- Create special files
	CAP_NET_ADMIN = nil,       --
	CAP_SETGID = nil,          --
	CAP_SETUID = nil,          --
	CAP_SYS_ADMIN = nil,       --
	CAP_SYS_BOOT = nil,        --
	CAP_SYSLOG = nil,          --
}

function Process:new(kernel, path)
	local proc = {
        pid  = 0, -- process id
        ppid = 0, -- parent process id
        ruid = 0, -- real uid
        euid = 0, -- effective uid
        suid = 0, -- saved setuid
        rgid = 0, -- real gid
        egid = 0, -- effective gid
        sgid = 0, -- saved setgid
        supplementary_groups = {},
        -- capabilities = 0,
        -- file_descriptors = {},
        current_directory = "/",
        argv = {},
        envp = {},
        dead = false,
        exit_code = nil,
        coroutine = nil,
        kernel = kernel
    }
    setmetatable(proc, self)
    self.__index = self

    proc:exec(path)
    return proc
end

-- Builds the sandboxed global environment for a process.
-- Exposes safe Lua builtins and the ProcessInterface syscalls.
function Process:make_env()
    local env = {
        -- Safe Lua standard library
        math      = math,
        string    = string,
        table     = table,
        ipairs    = ipairs,
        pairs     = pairs,
        next      = next,
        type      = type,
        tostring  = tostring,
        tonumber  = tonumber,
        select    = select,
        error     = error,
        assert    = assert,
        pcall     = pcall,
        xpcall    = xpcall,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        rawget    = rawget,
        rawset    = rawset,
        rawequal  = rawequal,
        rawlen    = rawlen,
        bitwise   = Bitwise,
    }

    -- Merge ProcessInterface functions in as globals
    for k, v in pairs(ProcessInterface.new(self)) do
        env[k] = v
    end

    env._ENV = env
    return env
end

function Process:exec(path)
    local resolved_path = Paths.resolve(path, self.current_directory)
    local vfs = self.kernel.vfs

    local driver = vfs:get_fs_driver(resolved_path)
    local inode = driver:get_inode(resolved_path)

    -- Must be a regular file
    if not Inode.get_file_type(inode, Inode.TYPE_REG) then
        error("ENOEXEC: not a regular file: " .. resolved_path)
    end

    -- Check execute permission using process credentials
    vfs:check_path_traversal(self, resolved_path)
    vfs:check_inode_perm(self, inode, Inode.MASK_EXEC, resolved_path)

    -- Read file as the kernel, bypassing the process's read permission
    local code = driver:read_file(inode, 0, inode.size)

    local chunk, err = load(code, "@" .. resolved_path, "t", self:make_env())
    if not chunk then
        error("ENOEXEC: " .. resolved_path .. ": " .. err)
    end

    self.coroutine = coroutine.create(chunk)
end

function Process:setuid(uid)
	if self.euid == 0 then
        self.ruid = uid
        self.euid = uid
        self.suid = uid
    else
        if uid == self.ruid then
            self.euid = uid
            self.suid = uid
        end
    end
end

function Process:seteuid(uid)
    if self.euid == 0 then
        self.euid = uid
    else
        if uid == self.ruid or uid == self.euid or uid == self.suid then
            self.euid = uid
        end
    end
end

function Process:setgid(gid)
    if self.euid == 0 then
        self.rgid = gid
        self.egid = gid
        self.sgid = gid
    else
        if gid == self.rgid or gid == self.egid or gid == self.sgid then
            self.egid = gid
        end
    end
end

function Process:setegid(gid)

end

-- Returns the effective gid plus any supplementary groups for a process.
function Process:get_gids()
    local gids = {self.egid}
    for _, gid in ipairs(self.supplementary_groups) do
        table.insert(gids, gid)
    end
    return gids
end


function Process:kill()

end

function Process:chdir(path)
	self.current_directory = Paths.resolve(path, self.current_directory)
end

return Process
