-- /bin/init.lua is the usermode entrypoint.
local hostnameFile = process.open("/etc/hostname", "r")
local hostname  = hostnameFile.readLine()
hostnameFile.close()
process.sethostname(hostname)

process.exec("/bin/login.lua")
