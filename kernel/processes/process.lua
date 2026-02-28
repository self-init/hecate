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
---@field coroutine coroutine
Process = {
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

function Process:new()
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
    }
    setmetatable(proc, self)
    self.__index = self

    return proc
end

function Process:fork()

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

function Process:setgid(proc, gid)
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

function Process:setegid(proc)

end

function Process:kill(proc)

end

function Process:chdir(proc)

end

function Process:spawn(proc)

end
