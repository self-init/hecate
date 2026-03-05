---@meta

---@class Driver
---@field arch Arch
local Driver = {}

---Creates a new instance of the driver.
---@param arch Arch Architecture the driver relies on.
---@return Driver The new driver object.
function Driver:new(arch) end

---Mounts the driver to the given path.
---@param path string Path of the mountpoint.
---@return Inode The Inode of the newly created file at the mountpoint.
function Driver:mount(path) end

---Unmounts the mountpoint at the given path.
---@param path string Path of the mountpoint.
function Driver:unmount(path) end

---Gets the Inode associated with a given path.
---@param path string Path.
---@return Inode Inode at the path.
function Driver:get_inode(path) end

---Gets the files in a directory.
---@param inode Inode Directory to read from.
---@return table<integer, string> Output table of files.
function Driver:read_dir(inode) end

---Creates a file as a child of the given directory inode.
---@param parent_inode Inode The parent directory
---@param name string The name of the new file.
---@param type integer The type of the new file (Inode.TYPE_*).
---@return Inode The newly created file.
function Driver:create_file(parent_inode, name, type) end

---Removes the given file.
---@param inode Inode
function Driver:destroy_file(inode) end

---Reads data from the given file.
---@param inode Inode File to read from.
---@param offset integer Offset from start of file to read.
---@param length integer Amount of data to read.
---@return any
function Driver:read_file(inode, offset, length) end

---Writes data to the given file/
---@param inode Inode File to write to.
---@param offset integer Offset from start of file to write.
---@param data any Data to write.
function Driver:write_file(inode, offset, data) end

return Driver
