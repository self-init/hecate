out = output
docsdir = docs

# ComputerCraft Variables
cc_kernel = $(out)/hecate-cc.lua
cc_kernel_mini = $(out)/hecate-cc-minified.lua
cc_installer = $(out)/hecate-cc-installer.lua

# Pure Lua Variables
native_kernel = $(out)/hecate-native.lua
native_kernel_mini = $(out)/hecate-native-minified.lua

# Luau Variables
luau_kernel = $(out)/hecate-luau.luau

rootfs = $(out)/rootfs.dat

# TypeScript is the source of truth; each per-arch tsconfig compiles and
# bundles kernel/**/*.ts directly to a single file in $(out) (luaBundle).
ts_sources := $(shell find kernel -type f -name "*.ts")
ts_configs := tsconfig.json tsconfig.cc.json tsconfig.native.json tsconfig.luau.json
root_files := $(shell find rootfs -type f -name "*.lua")

all: native-all computercraft-all luau rootfs

rootfs: $(rootfs)

native-all: native native-minified

native-minified: $(native_kernel_mini)

native: $(native_kernel)

luau: $(luau_kernel)

computercraft-all: computercraft-minified computercraft computercraft-installer

computercraft-minified: $(cc_kernel_mini)

computercraft: $(cc_kernel)

computercraft-installer: $(cc_installer)

$(rootfs): $(root_files) $(out)
	lua build/mkserialfs.lua rootfs/ > $(rootfs)

# luamin's -f (file read) is broken in some builds; feed via stdin instead.
$(native_kernel_mini): $(native_kernel)
	luamin -c < $(native_kernel) > $(native_kernel_mini)

$(native_kernel): $(ts_sources) $(ts_configs) $(out)
	npx tstl -p tsconfig.native.json --noEmitOnError

$(cc_installer): $(cc_kernel_mini) $(rootfs)
	lua build/mkinstaller.lua $(cc_kernel_mini) $(rootfs) > $(cc_installer)

$(cc_kernel_mini): $(cc_kernel)
	luamin -c < $(cc_kernel) > $(cc_kernel_mini)

$(cc_kernel): $(ts_sources) $(ts_configs) $(out)
	npx tstl -p tsconfig.cc.json --noEmitOnError

$(luau_kernel): $(ts_sources) $(ts_configs) $(out)
	npx tstl -p tsconfig.luau.json --noEmitOnError

$(out):
	mkdir $(out)

# NOTE: docs generation is stale post-migration. lua-language-server
# reads the old LuaLS (---@) annotations; the source is now TypeScript.
# Left here until the doc pipeline is migrated (e.g. typedoc). Not part
# of `all`, and invoking it will not reflect the current TS source.
documentation: $(docsdir)
	lua-language-server --doc=. --doc_out_path=./$(docsdir)

$(docsdir):
	mkdir $(docsdir)

clean:
	rm -rf $(out)
	rm -rf $(docsdir)
