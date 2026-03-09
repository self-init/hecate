local BaseTty = require("drivers.common.tty")

-- A PTY is a single character device with a full termios line discipline.
--
-- Data flow:
--   write_file(raw chars) → line discipline → read_queue → read_file (slave reads)
--   _write (echo / output processing) → output_buf → read_output (master reads)
--
-- Mount at a path like /dev/pty0. The writing process feeds raw input;
-- the reading process gets cooked lines.

---@class Pty: BaseTty
---@field output_buf table<integer, string>
local Pty = BaseTty:new()

---@param arch Arch
---@return Pty
function Pty:new(arch)
    local pty = BaseTty.new(self, arch)
    pty.output_buf = {}
    return pty
end

-- Echo and any output-processed data accumulate here.
-- Call read_output() to drain (e.g. for a terminal emulator to display).
function Pty:_write(data)
    table.insert(self.output_buf, data)
end

-- Read from the output side (echo + program output).
---@param length integer  0 = unlimited
---@return string?
function Pty:read_output(length)
    if #self.output_buf == 0 then return nil end
    local chunk = table.remove(self.output_buf, 1)
    if length and length > 0 and #chunk > length then
        table.insert(self.output_buf, 1, chunk:sub(length + 1))
        chunk = chunk:sub(1, length)
    end
    return chunk
end

return Pty
