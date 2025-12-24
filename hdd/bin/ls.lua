local strings = process.uselib("/lib/strings.lua")
local userlib = process.uselib("/lib/userlib.lua")

local args = process.getargv()

local paths = {}
local longMode = false
local displayAll = false

for idx=2, #args do
    local arg = args[idx]
    if arg:sub(1,2) == "--" then
        
    elseif arg:sub(1,1) == "-" then
        for i = 2, #arg do
            local argName = arg:sub(i,i)
            if argName == "l" then
                longMode = true
            elseif argName == "a" then
                displayAll = true
            end
        end
    else
        table.insert(paths, arg)
    end
end

local function listPath(path)
    local beforeDir = process.getcwd()
    local contents = process.readdir(path)
    if not contents then
        print("Can't read directory",path)
        return
    end
    for _,file in ipairs(contents) do
        process.chdir(path)
        local parts = {}
        for part in strings.gsplit(file, "/") do
            table.insert(parts, part)
        end
        local fileName = parts[#parts]
        if fileName == "" then goto continue end
        if fileName:sub(1,1) == "." and not displayAll then goto continue end
        if longMode then
            local fileStat = process.stat(file)
            local ownerName = userlib.getPasswdData(fileStat.user).username
            local outStr = fileStat.type
            outStr = outStr .. (fileStat.perms.user.read    and "r" or "-")
            outStr = outStr .. (fileStat.perms.user.write   and "w" or "-")
            outStr = outStr .. (fileStat.perms.user.execute and "x" or "-")
            outStr = outStr .. (fileStat.perms.group.read    and "r" or "-")
            outStr = outStr .. (fileStat.perms.group.write   and "w" or "-")
            outStr = outStr .. (fileStat.perms.group.execute and "x" or "-")
            outStr = outStr .. (fileStat.perms.all.read      and "r" or "-")
            outStr = outStr .. (fileStat.perms.all.write     and "w" or "-")
            outStr = outStr .. (fileStat.perms.all.execute   and "x" or "-")
            outStr = outStr .. " " ..   ownerName .. " " .. parts[#parts]
            print(outStr)
        else
            print(parts[#parts])
        end
        ::continue::
    end
    process.chdir(beforeDir)
end

if #paths > 0 then
    for _,path in ipairs(paths) do
        listPath(path)
    end
else
    listPath(".")
end


process.exit(0)