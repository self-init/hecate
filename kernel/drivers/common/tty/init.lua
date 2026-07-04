local BaseChrDev = require("drivers.common.basechrdev")
local Bitwise    = require("common.bitwise")
local Termios    = require("drivers.common.tty.termios")
local band       = Bitwise.band
local bor        = Bitwise.bor

-- Export constants so subclasses and callers can reference them
---@class BaseTty: BaseChrDev | TtyInterface
---@field termios    table
---@field input_buf  string
---@field read_queue table
---@field _esc_state string  "normal" | "esc" | "csi"
---@field _esc_buf   string  accumulated CSI parameter/intermediate bytes
local BaseTty    = BaseChrDev:new()

local function default_termios()
	return {
		iflag = Termios.ICRNL,
		oflag = bor(Termios.OPOST, Termios.ONLCR),
		cflag = 0,
		lflag = bor(bor(bor(Termios.ICANON, Termios.ECHO), Termios.ECHOE), Termios.ISIG),
		cc    = { [Termios.VINTR] = 3, [Termios.VERASE] = 8, [Termios.VKILL] = 21, [Termios.VEOF] = 4 },
	}
end

---@param arch Arch
---@return BaseTty
function BaseTty:new(arch)
	local tty      = BaseChrDev.new(self, arch) --[[@as BaseTty]]
	tty.termios    = default_termios()
	tty.input_buf  = ""
	tty.read_queue = {}
	tty._esc_state = "normal"
	tty._esc_buf   = ""
	return tty
end

-- ── VT100 / CSI escape sequence parser ───────────────────────────────────────

-- Handle a fully-accumulated CSI sequence.
-- params: bytes between ESC[ and the final byte, e.g. "3;5", "?25", "31"
-- final:  the final byte character, e.g. "H", "m", "h"
---@param params string
---@param final string
function BaseTty:_handle_csi(params, final)
	local args = {}
	for n in (params .. ";"):gmatch("(%d*);") do
		table.insert(args, tonumber(n) or 0)
	end
	local function p(i, default)
		local v = args[i]
		return (v and v ~= 0) and v or default
	end

	local w, h = self:_get_term_size()
	local cx, cy = self:_get_cursor_pos()

	if final == "H" or final == "f" then
		-- Cursor position: ESC[row;colH (1-based, defaults 1;1)
		self:_set_cursor_pos(
			math.max(1, math.min(p(2, 1), w)),
			math.max(1, math.min(p(1, 1), h))
		)
	elseif final == "A" then
		self:_set_cursor_pos(cx, math.max(1, cy - p(1, 1)))
	elseif final == "B" then
		self:_set_cursor_pos(cx, math.min(h, cy + p(1, 1)))
	elseif final == "C" then
		self:_set_cursor_pos(math.min(w, cx + p(1, 1)), cy)
	elseif final == "D" then
		self:_set_cursor_pos(math.max(1, cx - p(1, 1)), cy)
	elseif final == "J" then
		if p(1, 0) == 2 then self:_clear_screen() end
	elseif final == "K" then
		local n = p(1, 0)
		if n == 0 then
			self:_clear_to_eol()
		elseif n == 2 then
			self:_clear_line()
		end
	elseif final == "m" then
		if #args == 0 then args = { 0 } end
		for _, code in ipairs(args) do
			if code == 0 then
				self:_reset_colors()
			elseif code >= 30 and code <= 37 then
				self:_set_text_color(code)
			elseif code >= 40 and code <= 47 then
				self:_set_bg_color(code)
			end
		end
	elseif (final == "h" or final == "l") and params:sub(1, 1) == "?" then
		local mode = tonumber(params:sub(2)) or 0
		if mode == 25 then
			self:_set_cursor_visible(final == "h")
		end
	end
	-- Unrecognised sequences are silently discarded
end

---@param ch char
function BaseTty:_process_char(ch)
	local b = ch:byte()
	if self._esc_state == "normal" then
		if b == 27 then -- ESC
			self._esc_state = "esc"
		else
			self:_write_raw(ch)
		end
	elseif self._esc_state == "esc" then
		if ch == "[" then
			self._esc_state = "csi"
			self._esc_buf   = ""
		else
			self._esc_state = "normal"
		end
	elseif self._esc_state == "csi" then
		if b >= 0x40 and b <= 0x7E then
			self:_handle_csi(self._esc_buf, ch)
			self._esc_buf   = ""
			self._esc_state = "normal"
		else
			self._esc_buf = self._esc_buf .. ch
		end
	end
end

---@param inode Inode
---@param offset integer
---@param data any
function BaseTty:write_file(inode, offset, data)
	local s = tostring(data)
	if band(self.termios.oflag, Termios.OPOST) ~= 0 then
		if band(self.termios.oflag, Termios.ONLCR) ~= 0 then
			s = s:gsub("\n", "\r\n")
		end
	end
	self:_write(s)
end

-- Write data through the escape-sequence parser.
function BaseTty:_write(data)
	local i = 1
	while i <= #data do
		local ch = data:sub(i, i)
		if self._esc_state == "normal" and ch:byte() ~= 27 then
			-- Batch all consecutive plain characters into one _write_raw call
			local j = i + 1
			while j <= #data do
				if data:sub(j, j):byte() == 27 then break end
				j = j + 1
			end
			self:_write_raw(data:sub(i, j - 1))
			i = j
		else
			self:_process_char(ch)
			i = i + 1
		end
	end
end

-- Push a single raw character from the hardware into the line discipline.
---@param char string  single character
function BaseTty:push_input(char)
	local lflag = self.termios.lflag
	local cc    = self.termios.cc

	-- ICRNL: map carriage return to newline
	if band(self.termios.iflag, Termios.ICRNL) ~= 0 and char == "\r" then
		char = "\n"
	end

	if band(lflag, Termios.ICANON) ~= 0 then
		local b = char:byte()

		if b == cc[Termios.VERASE] then
			if #self.input_buf > 0 then
				self.input_buf = self.input_buf:sub(1, -2)
				if band(lflag, Termios.ECHO) ~= 0 and band(lflag, Termios.ECHOE) ~= 0 then
					self:_echo_erase(1)
				end
			end
		elseif b == cc[Termios.VKILL] then
			if band(lflag, Termios.ECHO) ~= 0 then
				self:_echo_erase(#self.input_buf)
			end
			self.input_buf = ""
		elseif b == cc[Termios.VEOF] then
			table.insert(self.read_queue, self.input_buf)
			self.input_buf = ""
		elseif char == "\n" then
			self.input_buf = self.input_buf .. char
			if band(lflag, Termios.ECHO) ~= 0 then self:write_file(nil, 0, char) end
			table.insert(self.read_queue, self.input_buf)
			self.input_buf = ""
		else
			self.input_buf = self.input_buf .. char
			if band(lflag, Termios.ECHO) ~= 0 then self:write_file(nil, 0, char) end
		end
	else
		if band(lflag, Termios.ECHO) ~= 0 then self:write_file(nil, 0, char) end
		table.insert(self.read_queue, char)
	end
end

---@param inode Inode
---@param offset integer
---@param length integer
---@return string?
function BaseTty:read_file(inode, offset, length)
	if #self.read_queue == 0 then return nil end
	local chunk = table.remove(self.read_queue, 1)
	if length > 0 and #chunk > length then
		table.insert(self.read_queue, 1, chunk:sub(length + 1))
		chunk = chunk:sub(1, length)
	end
	return chunk
end

-- ioctl request codes
BaseTty.TCGETS = 0x5401
BaseTty.TCSETS = 0x5402

---@param inode Inode
---@param request integer
---@param arg any
---@return any
function BaseTty:ioctl(inode, request, arg)
	if request == BaseTty.TCGETS then
		local t = {}
		for k, v in pairs(self.termios) do t[k] = v end
		t.cc = {}
		for k, v in pairs(self.termios.cc) do t.cc[k] = v end
		return t
	elseif request == BaseTty.TCSETS then
		self.termios = arg
	end
end

return BaseTty
