local ProcessInterface = {}

---@param process Process
---@return ProcessInterface
function ProcessInterface.new(process)
	---@class ProcessInterface
    local process_interface = {}
    local vfs = process.kernel.vfs

    function process_interface.exec(path)
    	process:exec(path)
    end

    function process_interface.read(path, offset, length)
        return vfs:read(process, path, offset, length)
    end

    function process_interface.write(path, offset, data)
        return vfs:write(process, path, offset, data)
    end

    function process_interface.read_dir(path)
        return vfs:read_dir(process, path)
    end

    function process_interface.print(...)
        local parts = {}
        for i = 1, select('#', ...) do
            parts[i] = tostring(select(i, ...))
        end
        vfs:write(process, "/dev/tty", 0, table.concat(parts, "\t") .. "\n")
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
