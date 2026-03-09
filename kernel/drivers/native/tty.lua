local BaseTty = require("drivers.common.tty")

---@class NativeTty: BaseTty
---@field _cx integer  tracked cursor column (1-based)
---@field _cy integer  tracked cursor row    (1-based)
---@field _cw integer
---@field _ch integer
local NativeTty = BaseTty:new()

function NativeTty:new(arch)
    local tty = BaseTty.new(self, arch)
    tty._cx = 1
    tty._cy = 1
    tty._cw = tonumber(os.getenv("COLUMNS")) or 80
    tty._ch = tonumber(os.getenv("LINES"))   or 24
    return tty
end

local function out(s)
    io.write(s)
    io.flush()
end

function NativeTty:_write_raw(str)
    out(str)
    -- Track cursor position so _get_cursor_pos() doesn't need a terminal query
    for i = 1, #str do
        local ch = str:sub(i, i)
        if ch == "\n" then
            self._cy = self._cy + 1
            self._cx = 1
        elseif ch == "\r" then
            self._cx = 1
        else
            self._cx = self._cx + 1
            if self._cx > self._cw then
                self._cx = 1
                self._cy = self._cy + 1
            end
        end
    end
end

function NativeTty:_echo_erase(n)
    out(string.rep("\8 \8", n))
    self._cx = math.max(1, self._cx - n)
end

function NativeTty:_set_cursor_pos(x, y)
    out(string.format("\27[%d;%dH", y, x))
    self._cx = x
    self._cy = y
end

function NativeTty:_get_cursor_pos()
    return self._cx, self._cy
end

function NativeTty:_get_term_size()
    return self._cw, self._ch
end

function NativeTty:_clear_screen()
    out("\27[2J\27[H")
    self._cx = 1
    self._cy = 1
end

function NativeTty:_clear_to_eol()
    out("\27[K")
end

function NativeTty:_clear_line()
    out("\27[2K\27[1G")
    self._cx = 1
end

function NativeTty:_set_text_color(ansi)
    out(string.format("\27[%dm", ansi))
end

function NativeTty:_set_bg_color(ansi)
    out(string.format("\27[%dm", ansi))
end

function NativeTty:_reset_colors()
    out("\27[0m")
end

function NativeTty:_set_cursor_visible(visible)
    out(visible and "\27[?25h" or "\27[?25l")
end

return NativeTty
