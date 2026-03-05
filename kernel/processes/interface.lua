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
        coroutine.yield()  -- suspend old coroutine; scheduler resumes the new one
    end

    -- Create a new child process running the given executable.
    -- Returns the child's PID.
    function process_interface.spawn(path)
        local Process = require("processes.process")
        local child = Process:new(process.kernel, path)
        child.ppid = process.pid
        procman:add_process(child)
        return child.pid
    end

    function process_interface.read(path, offset, length)
        return vfs:read_file(process, path, offset, length)
    end

    function process_interface.write(path, offset, data)
        return vfs:write_file(process, path, offset, data)
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

    return process_interface
end

return ProcessInterface
