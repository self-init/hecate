local BaseTty = require("drivers.common.tty")

-- ANSI colour code → CC colours constant
local ANSI_FG = {
    [30] = colours.black,  [31] = colours.red,    [32] = colours.green,
    [33] = colours.yellow, [34] = colours.blue,   [35] = colours.purple,
    [36] = colours.cyan,   [37] = colours.white,
}
local ANSI_BG = {
    [40] = colours.black,  [41] = colours.red,    [42] = colours.green,
    [43] = colours.yellow, [44] = colours.blue,   [45] = colours.purple,
    [46] = colours.cyan,   [47] = colours.white,
}

---@class CCTty: BaseTty
local CCTty = BaseTty:new()

function CCTty:_write_raw(ch)
    io.write(ch)
end

function CCTty:_echo_erase(n)
    local x, y = term.getCursorPos()
    term.setCursorPos(x - n, y)
    term.write(string.rep(" ", n))
    term.setCursorPos(x - n, y)
end

function CCTty:_set_cursor_pos(x, y)
    term.setCursorPos(x, y)
end

function CCTty:_get_cursor_pos()
    return term.getCursorPos()
end

function CCTty:_get_term_size()
    return term.getSize()
end

function CCTty:_clear_screen()
    term.clear()
    term.setCursorPos(1, 1)
end

function CCTty:_clear_to_eol()
    local x, y = term.getCursorPos()
    local w, _ = term.getSize()
    term.write(string.rep(" ", w - x + 1))
    term.setCursorPos(x, y)
end

function CCTty:_clear_line()
    term.clearLine()
    local _, y = term.getCursorPos()
    term.setCursorPos(1, y)
end

function CCTty:_set_text_color(ansi)
    if ANSI_FG[ansi] then term.setTextColour(ANSI_FG[ansi]) end
end

function CCTty:_set_bg_color(ansi)
    if ANSI_BG[ansi] then term.setBackgroundColour(ANSI_BG[ansi]) end
end

function CCTty:_reset_colors()
    term.setTextColour(colours.white)
    term.setBackgroundColour(colours.black)
end

function CCTty:_set_cursor_visible(visible)
    term.setCursorBlink(visible)
end

return CCTty
