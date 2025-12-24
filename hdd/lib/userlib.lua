local etcparse = process.uselib("/lib/etcparse.lua")

local passwdPath = "/etc/passwd"
local shadowPath = "/etc/shadow"

local passwdFormat =         {"username", "passwordType", "uid", "gid", "gecos", "home", "login"}
local passwdFormatIsNumber = {false     , false         , true , true , false  , false , false  }
local shadowFormat = {"username", "passwordHash", "lastChanged", "minAge", "maxAge", "warnPeriod", "inactivePeriod", "expirationDate", "reserved"}

function parsePasswdFile()
    local passwdFile = process.open(passwdPath, "r")
    local passwdFileString = passwdFile.readAll()
    passwdFile:close()
    local parsed = etcparse.parse(passwdFileString, passwdFormat, passwdFormatIsNumber)
    return parsed
end

function parseShadowFile()
    local shadowFile = open(shadowPath)
    local shadowFileString = shadowFile:getAll()
    shadowFile:close()

    local parsed = etcparse.parse(shadowFileString, shadowFormat)

    return parsed
end

local userlib = {}

function userlib.getPasswdData(uid)
    local parsed = parsePasswdFile()
    for _, user in ipairs(parsed) do
        if user.uid == uid then
            return user
        end
    end
end

function userlib.getPasswdDataByName(name)
    local parsed = parsePasswdFile()
    for _, user in ipairs(parsed) do
        if user.username == name then
            return user
        end
    end
end

function userlib:getShadowData(uid)

end

return userlib
