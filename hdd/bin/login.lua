local userlib = process.uselib("/lib/userlib.lua")

local loggedIn = false
local user = nil


while true do
    term.clear()
    term.setCursorPos(1,1)
    print("Logging in:")
    while not loggedIn do
        write("Username: ")
        local username = read()
        write("Password: ")
        local password = read("*")
        user = userlib.getPasswdDataByName(username)
        if user ~= nil then
            loggedIn = true
            print("Successfully logged in.")
        else
            print("Invalid login.")
        end
    end

    pid = process.spawn(user.login, {}, {setuid = user.uid, setgid = user.gid})
    process.wait(pid)
    loggedIn = false
end