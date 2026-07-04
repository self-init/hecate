---@class Error
local Error = {}

-- POSIX error codes
Error.ENOENT    = "ENOENT"    -- No such file or directory
Error.EACCES    = "EACCES"    -- Permission denied
Error.EBADF     = "EBADF"     -- Bad file descriptor
Error.EEXIST    = "EEXIST"    -- File already exists
Error.EISDIR    = "EISDIR"    -- Is a directory
Error.ENOEXEC   = "ENOEXEC"   -- Exec format error
Error.ENOTEMPTY = "ENOTEMPTY" -- Directory not empty
Error.ENOTDIR   = "ENOTDIR"   -- Not a directory

---@alias ErrorCode
--- | `Error.ENOENT`
--- | `Error.EACCES`
--- | `Error.EBADF`
--- | `Error.EEXIST`
--- | `Error.ENOEXEC`
--- | `Error.ENOTEMPTY`
--- | `Error.ENOTDIR`

---@class ErrorObject
---@field code string
---@field message string
local ErrorMeta = {
	---@param self ErrorObject
	---@return string
    __tostring = function(self)
        return self.code .. ": " .. self.message
    end
}

-- Create an error object without throwing it.
---@param code string   One of the Error.E* constants
---@param message string
---@return ErrorObject
function Error.err(code, message)
    return setmetatable({ code = code, message = message }, ErrorMeta)
end

-- Create and throw an error.
---@param code string
---@param message string
function Error.throw(code, message)
    error(Error.err(code, message), 2)
end

return Error
