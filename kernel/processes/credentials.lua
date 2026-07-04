---@class Credentials
---@field ruid number  real user id
---@field euid number  effective user id
---@field suid number  saved set-user-id
---@field rgid number  real group id
---@field egid number  effective group id
---@field sgid number  saved set-group-id
---@field supplementary_groups number[]
local Credentials = {}

function Credentials:new()
	local cred = {
		ruid                 = 0,
		euid                 = 0,
		suid                 = 0,
		rgid                 = 0,
		egid                 = 0,
		sgid                 = 0,
		supplementary_groups = {},
	}
	setmetatable(cred, self)
	self.__index = self
	return cred
end

function Credentials:setuid(uid)
	if self.euid == 0 then
		self.ruid = uid
		self.euid = uid
		self.suid = uid
	else
		-- Non-root may only set euid to ruid or suid; suid is never modified.
		if uid == self.ruid or uid == self.suid then
			self.euid = uid
		end
	end
end

function Credentials:seteuid(uid)
	if self.euid == 0 then
		self.euid = uid
	else
		if uid == self.ruid or uid == self.euid or uid == self.suid then
			self.euid = uid
		end
	end
end

function Credentials:setgid(gid)
	if self.euid == 0 then
		self.rgid = gid
		self.egid = gid
		self.sgid = gid
	else
		if gid == self.rgid or gid == self.egid or gid == self.sgid then
			self.egid = gid
		end
	end
end

function Credentials:setegid(gid)
	if self.euid == 0 then
		self.egid = gid
	else
		if gid == self.rgid or gid == self.egid or gid == self.sgid then
			self.egid = gid
		end
	end
end

-- Returns the effective gid plus any supplementary groups.
function Credentials:get_gids()
	local gids = { self.egid }
	for _, gid in ipairs(self.supplementary_groups) do
		table.insert(gids, gid)
	end
	return gids
end

return Credentials
