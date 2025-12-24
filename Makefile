out = output
cc_startup_file = $(out)/startup.lua
lib_file = $(out)/kernellib.lua

computercraft: $(cc_startup_file) $(lib_file) $(out)

kernellib: $(lib_file) $(out)

$(cc_startup_file): $(lib_file) $(out)
	build/join_files.sh $(cc_startup_file) $(lib_file) kernel/cc_startup.lua
	build/minify_lua.sh $(cc_startup_file)

$(lib_file): $(wildcard kernel/*.lua) $(out)
	> $(lib_file)
	build/join_files.sh $(lib_file) kernel/vfs/dentry.lua kernel/vfs/inode.lua kernel/kernel.lua

$(out):
	mkdir $(out)

clean:
	rm -rf $(out)
