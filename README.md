# Hecate
Hecate is a kernel-like program written in Lua, intended to be used with computercraft.

## Installation

### ComputerCraft
Get the latest version of the install script using wget.
```
wget https://raw.githubusercontent.com/self-init/hecate/refs/heads/master/cc_install.lua
```
Run it.
```
cc_install.lua
```

### Lua
Download `hecate-gen.lua` from the releases tab and run it:
```
lua hecate-gen.lua
```

## Building
The project has a build target for each compatible "architecture" of the kernel. To build the kernel, use make.

```
make computercraft
```
