# Hecate
Hecate is a Unix-like kernel written in TypeScript, compiled to Lua with [TSTL](https://typescripttolua.github.io/), intended to be used with ComputerCraft.

## Installation

### ComputerCraft
> **Warning:** the installer overwrites `startup.lua` (and `rootfs.dat`) in the current directory, then deletes itself and reboots. Back up any existing `startup.lua` first.

Download the latest installer from the releases page using wget.
```
wget https://github.com/self-init/hecate/releases/latest/download/hecate-cc-installer.lua
```
Run it.
```
hecate-cc-installer.lua
```

### Lua
Build the native kernel and root filesystem (see [Building](#building)), then run it from `output/`, where `rootfs.dat` must be in the working directory:
```
make native rootfs
cd output && lua hecate-native.lua
```

## Building
The project has a build target for each compatible "architecture" of the kernel. To build the kernel, use make.

```
make computercraft
```

## What works / What doesn't

**Works**
- Boots to a shell (`sh`) with `ls`, `echo`, `pwd`, `mkdir`, and `cd`
- VFS with mount points: a persistent SerialFS root and a RamFS `/dev`
- Cooperative MLFQ process scheduler with blocking I/O
- File descriptors, TTY line discipline with termios, and process credentials
- ComputerCraft and plain Lua (native) targets

**Doesn't (yet)**
- Pipes, redirection, and signals
- Error handling and logging are mid-rework
- The Luau target is a placeholder
- No automated test suite
- On non-Cobalt interpreters, a program in an infinite loop can freeze the kernel (see [Notes](#notes))

## Notes
Some functionality is limited depending on the interpreter used to run the program. The [Cobalt](https://github.com/cc-tweaked/Cobalt) used by computercraft runtime has better support for multitasking processes because it allows yielding from anywhere within a program. Other interpreters may see reduced functionality, like the kernel freezing when a program enters an infinite loop.
