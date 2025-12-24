local paths = {}

function paths.iterator(pathString)
    return pathString:gmatch("([^/]+)")
end

function paths.split(pathString)
    local parts = {}
    for part in paths.iterator(pathString) do
        table.insert(parts, part)
    end
    return parts
end

-- function paths.getDepth(pathString)
--     return #paths.split(pathString)
-- end

function paths.join(path1, ...)
    local joinedPath = path1
    for _,path in ipairs(...) do
        local joinedSuffix = joinedPath:gsub(#joinedPath) "/"
        local pathPrefix = path:gsub(1,1) == "/"
        if joinedSuffix and pathPrefix then
            joinedPath = joinedPath..path:gsub(2)
        elseif joinedSuffix or pathPrefix then
            joinedPath = joinedPath..path
        else
            joinedPath = joinedPath.."/"..path
        end
    end
    return joinedPath
end

function paths.resolve(pathString, workingDirectoryString)
    --local pathParts = {}

    -- Use relative path if path doesn't start with "/"
    if pathString:sub(1,1) ~= "/" then
        --pathParts = paths.split(workingDirectoryString)
        pathString = paths.join(workingDirectoryString, pathString)
    end

    local pathParts = {}

    for part in paths.iterator(pathString) do
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
