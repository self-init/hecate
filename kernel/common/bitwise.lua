local TableTools = require("common.tabletools")

local Bitwise = {}

if _VERSION == "Lua 5.3" or _VERSION == "Lua 5.4" then

    Bitwise.band    = load("return function(a,b) return a & b  end")()
    Bitwise.bor     = load("return function(a,b) return a | b  end")()
    Bitwise.bxor    = load("return function(a,b) return a ~ b  end")()
    Bitwise.bnot    = load("return function(a)   return ~a      end")()
    Bitwise.lshift  = load("return function(a,b) return a << b  end")()
    Bitwise.rshift  = load("return function(a,b) return a >> b  end")()
    Bitwise.arshift = load("return function(a,b) return a >> b  end")()

    Bitwise.btest = function(a, b)
        return Bitwise.band(a, b) ~= 0
    end

    Bitwise.extract = function(a, start_bit, width)
        width = width or 1
        local mask = Bitwise.lshift(1, width) - 1
        return Bitwise.band(Bitwise.rshift(a, start_bit), mask)
    end

    Bitwise.replace = function(a, value, start_bit, width)
        width = width or 1
        local mask = Bitwise.lshift(Bitwise.lshift(1, width) - 1, start_bit)
        value = Bitwise.lshift(value, start_bit)
        return Bitwise.bor(Bitwise.band(a, Bitwise.bnot(mask)), Bitwise.band(value, mask))
    end

    Bitwise.lrotate = function(a, b)
        b = b % 32
        return Bitwise.bor(Bitwise.lshift(a, b), Bitwise.rshift(a, 32 - b))
    end

    Bitwise.rrotate = function(a, b)
        b = b % 32
        return Bitwise.bor(Bitwise.rshift(a, b), Bitwise.lshift(a, 32 - b))
    end

elseif Bitwise then

    Bitwise.band    = Bitwise.band
    Bitwise.bor     = Bitwise.bor
    Bitwise.bxor    = Bitwise.bxor
    Bitwise.bnot    = Bitwise.bnot
    Bitwise.lshift  = Bitwise.lshift
    Bitwise.rshift  = Bitwise.rshift
    Bitwise.arshift = Bitwise.arshift
    Bitwise.btest   = Bitwise.btest
    Bitwise.extract = Bitwise.extract
    Bitwise.replace = Bitwise.replace
    Bitwise.lrotate = Bitwise.lrotate
    Bitwise.rrotate = Bitwise.rrotate

else
    error("common.bitwise requires Lua 5.2 or newer")
end

return TableTools.freeze(Bitwise)
