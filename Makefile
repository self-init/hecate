out = output
cc_startup_file = $(out)/hecate-cc.lua
generic_startup_file = $(out)/hecate-gen.lua
lib_file = $(out)/hecate-kernel.lua

all: kernellib generic computercraft

generic: $(generic_startup_file)

computercraft: $(cc_startup_file)

kernellib: $(lib_file)

$(generic_startup_file): $(lib_file) $(out)
	build/join_files.sh $(generic_startup_file) $(lib_file) kernel/arch/generic/*.lua
	build/minify_lua.sh $(generic_startup_file)

$(cc_startup_file): $(lib_file) $(out)
	build/join_files.sh $(cc_startup_file) $(lib_file) kernel/arch/cc/*.lua
	build/minify_lua.sh $(cc_startup_file)

$(lib_file): $(filter-out $(meta_file), $(wildcard kernel/*.lua)) $(out)
	> $(lib_file)
	build/join_files.sh $(lib_file) kernel/common/*.lua kernel/vfs/*.lua kernel/processes/*.lua kernel/drivers/*.lua kernel/kernel.lua

$(out):
	mkdir $(out)

clean:
	rm -rf $(out)
