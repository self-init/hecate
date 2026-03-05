out = output

# ComputerCraft Variables
cc_kernel = $(out)/hecate-cc.lua
cc_kernel_mini = $(out)/hecate-cc-minified.lua
cc_installer = $(out)/hecate-cc-installer.lua

# Pure Lua Variabels
native_kernel = $(out)/hecate-native.lua
native_kernel_mini = $(out)/hecate-native-minified.lua

rootfs = $(out)/rootfs.dat
kernel_file = $(out)/hecate-kernel.lua
all_sources := $(shell find kernel -type f -name "*.lua")
root_files := $(shell find rootfs -type f -name "*.lua")

all: kernel native-all computercraft-all rootfs

rootfs: $(rootfs)

native-all: native native-minified

native-minified: $(native_kernel_mini)

native: $(native_kernel)

computercraft-all: computercraft-minified computercraft computercraft-installer

computercraft-minified: $(cc_kernel_mini)

computercraft: $(cc_kernel)

computercraft-installer: $(cc_installer)

kernel: $(kernel_file)

$(rootfs): $(root_files)
	lua build/mkserialfs.lua rootfs/ > $(rootfs)

$(native_kernel_mini): $(native_kernel)
	luamin -f $(native_kernel) > $(native_kernel_mini)

$(native_kernel): $(all_sources) $(out)
	lua build/bundle.lua kernel/arch/native/startup.lua kernel > $(native_kernel)

$(cc_installer): $(cc_kernel_mini) $(rootfs)
	lua build/mkinstaller.lua $(cc_kernel_mini) $(rootfs) > $(cc_installer)

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
