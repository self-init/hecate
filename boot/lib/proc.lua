-- Proc kernel library
-- Provides an interface between processes and the kernel, and controls how they are run.

local processStates = {"Running", "Uninterruptible Sleep", "Interruptible Sleep", "Stopped", "Zombie"}

local processes = {}
local highestPid = 0

local proc = {}

function copyInjectEnv(env, proc)
    local copy = tabletools.shallowcopy(env)
    copy.process = proc
    return copy
end

function proc.getDefaultProcessInfo()
    return {
        coroutine = nil,
        pid = 0,
        ppid = 0,
        uid = {
            real = 0,
            effective = 0,
            saved = 0,
        },
        gid = {
            real = 0,
            effective = 0,
            saved = 0,
        },
        dead = false,
        groups = {},
        hook = nil,
        argv = {},
        exit = nil,
        fileDescriptors = {},
        currentDirectory  = "/"
    }
end

function proc.new(file, baseEnv, processInfo)
    local newProc = {}

    local process = tabletools.deepcopy(processInfo)
    process.ppid = process.pid
    highestPid = highestPid + 1
    process.pid = highestPid

    local envCopy = copyInjectEnv(baseEnv, newProc)

    local fn = loadfile(file, envCopy)
    
    if fn ~= nil then
        process.coroutine = coroutine.create(fn)
    end

    function newProc.sethostname(hostname)
        if process.uid.effective == 0 then
            os.setComputerLabel(hostname)
        end
    end

    function newProc.gethostname()
        return os.getComputerLabel()
    end

    function newProc.stat(path)
        local resolvedPath = files.resolvePath(path, process.currentDirectory)
        local fileInode = files.getInodeFromPath(resolvedPath)
        return {
            perms = fileInode.perms,
            user  = fileInode.user,
            group = fileInode.group,
            type  = fileInode.type
        }
    end

    function newProc.chmod(path, permStr)
        local resolvedPath = files.resolvePath(path, process.currentDirectory)
        local parsedPerms = inode.parsePerms(permStr)
        local fileInode = files.getInodeFromPath(resolvedPath)
        if fileInode.user == process.uid.effective then
            fileInode.perms = parsedPerms
        end
    end

    function newProc.chown(path, newOwner, newGroup)
        local resolvedPath = files.resolvePath(path, process.currentDirectory)
        local fileInode = files.getInodeFromPath(resolvedPath)
        if process.uid.effective == 0 and newOwner ~= -1 then
            fileInode.owner = newOwner
        end
    end

    function newProc.reboot(mode)
        if process.uid.effective == 0 then
            if mode == "shutdown" then
                os.shutdown()
            elseif mode == "reboot" then
                os.reboot()
            end
        end
    end

    function newProc.getcwd()
        return process.currentDirectory
    end

    function newProc.chdir(path)
        local resolvedPath = files.resolvePath(path, process.currentDirectory)
        if files.getAccess(resolvedPath, process.uid.effective, {process.gid.effective}) then
            if files.getPermissions(resolvedPath, process.uid.effective, {process.gid.effective}).execute then
                process.currentDirectory = resolvedPath
                return true
            end
            return false
        end
        return false
    end

    function newProc.exit(code)
        process.dead = true
        process.exit = code
        coroutine.yield()
    end

    function newProc.wait(pid)
        if processes[pid] ~= nil and processes[pid].ppid == process.pid then
            while processes[pid] ~= nil do
                coroutine.yield()
            end 
        end 
    end

    function newProc.open(path, mode)
        return files.open(path, mode)
    end

    function newProc.readdir(path)
        local resolvedPath = files.resolvePath(path, process.currentDirectory)
        local perms = files.getPermissions(resolvedPath, process.uid.effective, {process.gid.effective})
        if perms.read then
            return files.readDir(resolvedPath)
        else
            return false
        end
    end

    function newProc.uselib(path)
        return loadfile(files.getRealPath(path), envCopy)()
    end

    function newProc.geteuid()
        return process.uid.effective
    end

    function newProc.setuid(uid)
        if process.uid.effective == 0 then
            process.uid.real = uid
            process.uid.effective = uid
            process.uid.saved = uid
        else
            if uid == process.uid.real then
                process.uid.effective = uid
                process.uid.saved = uid
            end
        end
    end


    function newProc.seteuid(uid)
        if process.uid.effective == 0 then
            process.uid.effective = uid
        else
            if uid == process.uid.real or uid == process.uid.effective or uid == process.uid.saved then
                process.uid.effective = uid
            end
        end
    end


    function newProc.setgid(gid)
        if process.uid.effective == 0 then
            process.gid.real = gid
            process.gid.effective = gid
            process.gid.saved = gid
        else
            if gid == process.gid.real or gid == process.gid.effective or gid == process.gid.saved then
                process.gid.effective = gid
            end
        end
    end


    function newProc.setegid(process, gid)

    end

    function newProc.spawn(path, argv, args)
        local newprocess = proc.new(files.getRealPath(path), baseEnv, process)
        if args ~= nil then
            if args.setgid ~= nil then
                newprocess.hook.setgid(args.setgid)
            end
            if args.setuid ~= nil then
                newprocess.hook.setuid(args.setuid)
            end
        end
        argv = argv or {}
        newprocess.argv = argv
        return newprocess.pid
    end

    function newProc.getargv()
        return process.argv
    end

    function newProc.exec(path, argv)
        argv = argv or {}
        --local fileInode = inode.getFileInode(path)
        local canRun = false
        if process.uid.effective == 0 then
            canRun = true
        end
        -- elseif inode.getUserPerms(fileInode).execute then
        --     canRun = true
        -- end 
        if not canRun then return end
        -- if fileInode.perms.special.setuid then
        --     process.uid.saved = fileInode.user
        -- end
        -- if fileInode.perms.special.setgid then
        --     process.gid.saved = fileInode.group
        -- end
        local fn = loadfile(files.getRealPath(path), copyInjectEnv(baseEnv, newProc))
        process.coroutine = coroutine.create(fn)
        process.argv = argv
        coroutine.yield()
    end

    process.hook = newProc

    processes[process.pid] = process

    return process
end

function proc.start()
    while #processes >= 1 do
        os.startTimer(0)
        event = table.pack(os.pullEventRaw())
        for _,process in pairs(processes) do
            if coroutine.status(process.coroutine) == "dead" or process.dead then
                processes[process.pid] = nil
            else
                local success, result = coroutine.resume(process.coroutine, table.unpack(event))
                if not success then
                    print(result)
                end
            end
        end
    end
end

return tabletools.freeze(proc)