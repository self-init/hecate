local strings = {}

function strings.gsplit(str, delim)
    return (str..delim):gmatch("(.-)"..delim)
end

return strings