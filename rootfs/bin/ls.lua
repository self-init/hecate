local dir = argv[2] or "."   -- default to cwd if no argument given
for _, entry in ipairs(read_dir(dir)) do
    write(1, entry .. "\n")
end
