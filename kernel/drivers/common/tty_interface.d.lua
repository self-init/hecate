---The TtyInterface class contains definitions for functions that must be
--- implemented by classes inheriting from BaseTty, in order to ensure proper
--- functionality.
---@class TtyInterface
local TtyInterface = {}

---Write a single raw character to the physical terminal.
---@param ch char
function TtyInterface:_write_raw(ch)
    error("BaseTty:_write_raw not implemented")
end

---Erase n characters at the current cursor position.
---@param n integer Number of characters to erase
function TtyInterface:_echo_erase(n) end

---Move cursor to absolute position (1-based).
---@param x integer
---@param y integer
function TtyInterface:_set_cursor_pos(x, y) end

---Return current cursor position (x, y).
---@return integer
---@return integer
function TtyInterface:_get_cursor_pos() return 1, 1 end

---Return terminal dimensions (width, height).
---@return integer
---@return integer
function TtyInterface:_get_term_size() return 80, 24 end

---Clear the entire screen and home the cursor.
function TtyInterface:_clear_screen() end

---Clear from the cursor to the end of the current line; cursor does not move.
function TtyInterface:_clear_to_eol() end

---Clear the entire current line; move cursor to column 1.
function TtyInterface:_clear_line() end

---Set foreground colour from an ANSI code (30–37).
---@param ansi integer
function TtyInterface:_set_text_color(ansi) end

---Set background colour from an ANSI code (40–47).
---@param ansi integer
function TtyInterface:_set_bg_color(ansi) end

---Reset colours to terminal defaults.
function TtyInterface:_reset_colors() end

---Show or hide the cursor.
---@param visible boolean
function TtyInterface:_set_cursor_visible(visible) end

return TtyInterface
