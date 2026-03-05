---@class TwoWayMap<K, V>
---@field forward table<K, V>
---@field backward table<V, K>
local TwoWayMap = {}

---@generic K, V
---@return TwoWayMap<K, V>
function TwoWayMap:new()
	local map = {
		forward = {},
		backward = {}
	}
	setmetatable(map, self)
	self.__index = self

	return map
end

---@generic K, V
---@param key K
---@param value V
function TwoWayMap:set(key, value)
	self.forward[key] = value
	self.backward[value] = key
end

---@generic K, V
---@overload fun(self: TwoWayMap<K, V>, key: K): V
---@overload fun(self: TwoWayMap<K, V>, key: V): K
---@param key K | V
---@return V | K
function TwoWayMap:get(key)
    if self.forward[key] ~= nil then
        return self.forward[key]
    else
        return self.backward[key]
    end
end

---@generic K, V
---@param key K | V
function TwoWayMap:remove(key)
	local value = self.forward[key]
	if value then
		self.forward[key] = nil
		self.backward[value] = nil
	else
		value = self.backward[key]
		self.backward[key] = nil
		self.forward[value] = nil
	end
end

return TwoWayMap
