-- boot.lua is the first file that is executed to start the OS.
-- It initializes the virtual file system before passing control off to the initial program, /bin/init.lua
-- At the moment it depends on CraftOS apis, and doesn't have it's own bios.

print("Booting OS")
print("Building boot environment")
local bootEnv = {}

for name,value in pairs(_G) do
    bootEnv[name] = value
end

print("Loading boot libraries")
local loadOrder = {"tabletools", "inode", "dentry", "files", "proc"}

local function loadBootLibrary(libraryName, withEnv)
    return loadfile("/boot/lib/"..libraryName..".lua", withEnv)()
end

for _, libraryName in pairs(loadOrder) do
    write("  Loading "..libraryName.."... ")
    bootEnv[libraryName] = loadBootLibrary(libraryName, bootEnv)
    print("Done.")
end

print("Building user environment")
local userEnv = {}

local blacklist={fs=true,os=true,_G=true,loadfile=true}

for name,value in pairs(_G) do
    if not blacklist[name] then
        userEnv[name] = value
    else
        print("  Unloading "..name..".")
    end
end

print("Building virtual filesystem")
print("  Mounting hdd to /")
bootEnv["files"].buildDriveFs("/hdd", "/", 0, 0, "0555")

print("Starting usermode")
sleep(1)

bootEnv["proc"].new("/hdd/bin/init.lua", userEnv, bootEnv["proc"].getDefaultProcessInfo())
bootEnv["proc"].start()
write("All processes ended, shutting down.")
os.shutdown()
