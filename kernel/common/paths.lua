local Paths = {}

function Paths.iterator(path_string)
    return path_string:gmatch("([^/]+)")
end

function Paths.split(path_string)
    local parts = {}
    for part in Paths.iterator(path_string) do
        table.insert(parts, part)
    end
    return parts
end

-- function paths.getDepth(pathString)
--     return #paths.split(pathString)
-- end
--
---@param path1 string
function Paths.join(path1, ...)
    local joined_path = path1
    for _, path in ipairs({...}) do
        local joined_suffix = joined_path:sub(-1) == "/"
        local path_prefix = path:sub(1, 1) == "/"
        if joined_suffix and path_prefix then
            joined_path = joined_path .. path:sub(2)
        elseif joined_suffix or path_prefix then
            joined_path = joined_path .. path
        else
            joined_path = joined_path .. "/" .. path
        end
    end
    return joined_path
end

-- Returns all parent directories for a path in order from root.
-- Used for checking execute permission during path traversal.
-- e.g., "/a/b/c" -> {"/", "/a", "/a/b"}
-- e.g., "/a"     -> {"/"}
-- e.g., "/"      -> {}
function Paths.parent_dirs(path_string)
    local parts = Paths.split(path_string)
    if #parts == 0 then return {} end
    local dirs = {"/"}
    for i = 1, #parts - 1 do
        table.insert(dirs, "/" .. table.concat(parts, "/", 1, i))
    end
    return dirs
end

function Paths.resolve(path_string, working_directory_string)
    --local pathParts = {}

    -- Use relative path if path doesn't start with "/"
    if path_string:sub(1,1) ~= "/" then
        --pathParts = paths.split(workingDirectoryString)
        path_string = Paths.join(working_directory_string, path_string)
    end

    local pathParts = {}

    for part in Paths.iterator(path_string) do
        if part == "." then
            goto continue
        elseif part == ".." then
            table.remove(pathParts, #pathParts)
        else
            table.insert(pathParts, part)
        end

        ::continue::
    end

    local resolvedPath = table.concat(pathParts, "/")
    return "/"..resolvedPath
end

return Paths
