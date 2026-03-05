#!/usr/bin/env lua

-- mkinstaller.lua: Pack a bundled kernel .lua and a SerialFS .dat into a
-- single self-extracting Lua file.
--
-- Usage: lua mkinstaller.lua <kernel.lua> <rootfs.dat> > output.lua
--   kernel.lua   Bundled kernel (output of bundle.lua)
--   rootfs.dat   SerialFS image (output of mkserialfs.lua)
--
-- When the output file is run it writes rootfs.dat to the working directory
-- then executes the kernel in-memory.

local kernel_path = arg[1]
local dat_path    = arg[2]

if not kernel_path or not dat_path then
    io.stderr:write("Usage: lua mkinstaller.lua <kernel.lua> <rootfs.dat> > output.lua\n")
    os.exit(1)
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

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

-- Extract the basename of a path (no directory component)
local function basename(path)
    return path:match("([^/\\]+)$") or path
end

-- ── Read inputs ───────────────────────────────────────────────────────────────

local kernel_src = read_file(kernel_path)
local dat_src    = read_file(dat_path, "rb")
local dat_name   = basename(dat_path)

-- ── Emit installer ────────────────────────────────────────────────────────────

io.write("-- Bundled by mkinstaller.lua\n")
io.write("-- DO NOT EDIT -- edit the source files and re-run mkinstaller.lua\n\n")

-- Write the .dat file to disk so SerialFS can find it on startup
io.write("-- Extract: " .. dat_name .. "\n")
io.write("do\n")
io.write("  local f = assert(io.open(" .. string.format("%q", dat_name) .. ", \"wb\"))\n")
io.write("  f:write(" .. safe_longstr(dat_src) .. ")\n")
io.write("  f:close()\n")
io.write("end\n\n")

-- Execute the kernel inline via load() — no second file needed
io.write("-- Kernel: " .. basename(kernel_path) .. "\n")
io.write("local _kernel, _err = load(" .. safe_longstr(kernel_src) .. ")\n")
io.write("if not _kernel then error(_err) end\n")
io.write("_kernel()\n")
