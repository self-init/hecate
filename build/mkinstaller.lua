#!/usr/bin/env lua

-- mkinstaller.lua: Pack a bundled kernel .lua and a SerialFS .dat into a
-- single self-extracting Lua file.
--
-- Usage: lua mkinstaller.lua <kernel.lua> <rootfs.dat> > output.lua
--   kernel.lua   Bundled kernel (output of bundle.lua)
--   rootfs.dat   SerialFS image (output of mkserialfs.lua)
--
-- When the output file is run it writes both files to the working directory.

local kernel_path = arg[1]
local dat_path    = arg[2]

if not kernel_path or not dat_path then
    io.stderr:write("Usage: lua mkinstaller.lua <kernel.lua> <rootfs.dat> > output.lua\n")
    os.exit(1)
end

local function read_file(path, mode)
    local f, err = io.open(path, mode or "r")
    if not f then
        io.stderr:write("Error: cannot open " .. path .. ": " .. err .. "\n")
        os.exit(1)
    end
    local content = f:read("*a")
    f:close()
    return content
end

-- Find the minimum long-string level that can safely wrap content.
-- Scans for all ]=*] sequences and uses one more = than the longest found.
local function safe_longstr(content)
    local max = -1
    for eqs in content:gmatch("%](%=*)%]") do
        if #eqs > max then max = #eqs end
    end
    local eq = string.rep("=", max + 1)
    return "[" .. eq .. "[\n" .. content .. "]" .. eq .. "]"
end

local kernel_src  = read_file(kernel_path)
local dat_src     = read_file(dat_path, "rb")

local function emit_file(name, content)
    io.write("do -- Extract: " .. name .. "\n")
    io.write("  local f = assert(io.open(" .. string.format("%q", name) .. ", \"wb\"))\n")
    io.write("  f:write(" .. safe_longstr(content) .. ")\n")
    io.write("  f:close()\n")
    io.write("end\n\n")
end

io.write('print("Installing Hecate...")')
emit_file("rootfs.dat", dat_src)
emit_file("startup.lua", kernel_src)
io.write('print("Files successfully installed.")')
io.write('print("Deleting installer.")')
io.write('fs.delete(shell.getRunningProgram())')
io.write('os.reboot()')
