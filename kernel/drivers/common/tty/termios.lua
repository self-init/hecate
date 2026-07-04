---@enum Termios
local Termios = {
	-- lflag bits
	ISIG   = 0x0001, -- signal generation (^C, ^Z)
	ICANON = 0x0002, -- canonical (line-buffered) input
	ECHO   = 0x0008, -- echo input characters
	ECHOE  = 0x0010, -- echo erase as BS-SP-BS
	-- iflag bits
	ICRNL  = 0x0100, -- map CR to NL on input
	-- oflag bits
	OPOST  = 0x0001, -- enable output processing
	ONLCR  = 0x0004, -- map NL to CR-NL on output
	-- c_cc indices
	VINTR  = 1, -- interrupt char (^C, byte 3)
	VERASE = 2, -- erase char    (^H, byte 8)
	VKILL  = 3, -- kill line     (^U, byte 21)
	VEOF   = 4, -- end-of-file   (^D, byte 4)
}

return Termios
