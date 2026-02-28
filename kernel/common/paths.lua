Paths = {}

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

function Paths.join(path1, ...)
    local joined_path = path1
    for _,path in ipairs(...) do
        local joined_suffix = joined_path:gsub(#joined_path) "/"
        local path_prefix = path:gsub(1,1) == "/"
        if joined_suffix and path_prefix then
            joined_path = joined_path..path:gsub(2)
        elseif joined_suffix or path_prefix then
            joined_path = joined_path..path
        else
            joined_path = joined_path.."/"..path
        end
    end
    return joined_path
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
