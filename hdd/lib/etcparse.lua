local strings = process.uselib("/lib/strings.lua")

local etcparse = {}

function etcparse.parse(str, format, formatIsNumber)
    local parsedFile = {}

    for line in strings.gsplit(str, "\n") do
        parsedFile[#parsedFile+1] = etcparse.parseLine(line, format, formatIsNumber)
    end

    return parsedFile
end

function etcparse.parseLine(lineString, format, formatIsNumber)
    local parsedEntry  = {}
    local idx = 1

    for data in strings.gsplit(lineString, ":") do
        if formatIsNumber[idx] then
            parsedEntry[format[idx]] = tonumber(data)
        else
            parsedEntry[format[idx]] = data
        end
        
        idx = idx + 1
    end

    return parsedEntry
end

function etcparse.toLine(lineData, format)
    local lineString = ""

    for i,name in ipairs(format) do
        lineString = lineString..lineData[name]..":"
    end

    return lineString:sub(1,-2)
end

return etcparse