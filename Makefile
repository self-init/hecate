out = output
cc_startup_file = $(out)/hecate-cc.lua
generic_startup_file = $(out)/hecate-gen.lua
kernel_file = $(out)/hecate-kernel.lua

all: kernel generic computercraft

generic: $(generic_startup_file)

computercraft: $(cc_startup_file)

kernel: $(kernel_file)

$(generic_startup_file): $(kernel_file) $(out)
	build/join_files.sh $(generic_startup_file) $(kernel_file) kernel/arch/generic/*.lua
	build/minify_lua.sh $(generic_startup_file)

$(cc_startup_file): $(kernel_file) $(out)
	build/join_files.sh $(cc_startup_file) $(kernel_file) kernel/arch/cc/*.lua
	build/minify_lua.sh $(cc_startup_file)

$(kernel_file): $(filter-out $(meta_file), $(wildcard kernel/*.lua)) $(out)
	> $(kernel_file)
	build/join_files.sh $(kernel_file) kernel/common/*.lua kernel/vfs/*.lua kernel/processes/*.lua kernel/drivers/*.lua kernel/kernel.lua

$(out):
	mkdir $(out)

clean:
	rm -rf $(out)
