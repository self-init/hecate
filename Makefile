out = output

# ComputerCraft Variables
cc_kernel = $(out)/hecate-cc.lua
cc_kernel_mini = $(out)/hecate-cc-minified.lua

# Pure Lua Variabels
generic_kernel = $(out)/hecate-gen.lua
generic_kernel_mini = $(out)/hecate-gen-minified.lua

kernel_file = $(out)/hecate-kernel.lua
all_sources := $(shell find kernel -type f -name "*.lua")

all: kernel generic generic-minified computercraft computercraft-minified

generic-minified: $(generic_kernel_mini)

generic: $(generic_kernel)

computercraft-minified: $(cc_kernel_mini)

computercraft: $(cc_kernel)

kernel: $(kernel_file)

$(generic_kernel_mini): $(generic_kernel)
	luamin -f $(generic_kernel) > $(generic_kernel_mini)

$(generic_kernel): $(all_sources) $(out)
	lua build/bundle.lua kernel/arch/generic/startup.lua kernel > $(generic_kernel)

$(cc_kernel_mini): $(cc_kernel)
	luamin -f $(cc_kernel) > $(cc_kernel_mini)

$(cc_kernel): $(all_sources) $(out)
	lua build/bundle.lua kernel/arch/cc/startup.lua kernel > $(cc_kernel)

$(kernel_file): $(all_sources) $(out)
	lua build/bundle.lua kernel/kernel.lua kernel > $(kernel_file)

$(out):
	mkdir $(out)

clean:
	rm -rf $(out)
