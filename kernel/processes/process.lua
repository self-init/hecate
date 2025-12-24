local process = {}

-- Process capabilities, see manpage capabilities(7)
-- More may be added later
                                  -- [ Capabilities ]
process.CAP_CHOWN = nil           --
process.CAP_DAC_OVERRIDE = nil    --
process.CAP_DAC_READ_SEARCH = nil --
process.CAP_KILL = nil            -- Kill arbitrary processes
process.CAP_MKNOD = nil           -- Create special files
process.CAP_NET_ADMIN = nil       --
process.CAP_SETGID = nil          --
process.CAP_SETUID = nil          --
process.CAP_SYS_ADMIN = nil       --
process.CAP_SYS_BOOT = nil        --
process.CAP_SYSLOG = nil          --

function process.spawn_initial_process()
    return {
        pid  = 0, -- process id
        ppid = 0, -- parent process id
        ruid = 0, -- real uid
        euid = 0, -- effective uid
        suid = 0, -- saved setuid
        rgid = 0, -- real gid
        egid = 0, -- effective gid
        sgid = 0, -- saved setgid
        supplementary_groups = {},
        capabilities = 0,
        file_descriptors = {},
        current_directory = "/",
        argv = {},
        dead = false,
        exit_code = nil,
        coroutine = nil,
    }
end

function process.setuid(proc, uid)
    if proc.euid == 0 then
        proc.ruid = uid
        proc.euid = uid
        proc.suid = uid
    else
        if uid == proc.ruid then
            proc.euid = uid
            proc.suid = uid
        end
    end
end

function process.seteuid(proc, uid)
    if proc.euid == 0 then
        proc.euid = uid
    else
        if uid == proc.ruid or uid == proc.euid or uid == proc.suid then
            proc.euid = uid
        end
    end
end

function process.setgid(proc, gid)
    if process.euid == 0 then
        process.rgid = gid
        process.egid = gid
        process.sgid = gid
    else
        if gid == process.rgid or gid == process.egid or gid == process.sgid then
            process.egid = gid
        end
    end
end

function process.setegid(proc)

end

function process.kill(proc)

end

function process.chdir(proc)

end

function process.spawn(proc)

end
