local userlib = process.uselib("/lib/userlib.lua")
local strings = process.uselib("/lib/strings.lua")

local user = userlib.getPasswdData(process.geteuid())
process.chdir(user.home)

local function displayPrompt()
    write("["..user.username.."@"..process.gethostname().." "..process.getcwd().."]$ ")
end

local function runCommand(commandString)
    local parts = {}
    for part in strings.gsplit(commandString, " ") do
        table.insert(parts, part)
    end

    local name = parts[1]

    if name == "" then return end

    if name == "cd" then 
        newDir = parts[2]
        if newDir:sub(1,1) == "~" then
            newDir = user.home .. newDir:sub(2)
        end
        if not process.chdir(newDir) then
            print("No such file or directory:",newDir)
        end
        return
    end

    if name == "chmod" then
        process.chmod(parts[2], parts[3])
        return
    end

    if name == "exit" then
        process.exit(0)
    end
    pid = process.spawn("/bin/"..name..".lua", parts)
    process.wait(pid)
end

local running = true
while running do
    displayPrompt()
    local cmd = read()
    runCommand(cmd)
end
