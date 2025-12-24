# Syscalls

> ### exit(code: int)

Ends the current process.

**Arguments** \
`code: int` The exit code of the process.

**Returns** \
Has no return value

> ### exec(path: string, argv: {string}?)

Executes the given file, replacing the current process.

**Arguments** \
`path: string` - The path to the program to be spawned. \
`argv: {string}?` - Arguments to be passed to the new process that can be accessed with `getargv()` \

**Returns** \
Has no return value

> ### spawn(path: string, argv: {string}?, args?): any

Spawns a new process

**Arguments** \
`path: string` - The path to the program to be spawned. \
`argv: {string}?` - Arguments to be passed to the new process that can be accessed with `getargv()` \
`args: table?` - Additional arguments that can modify the spawned process. `setuid: int?` Sets the uid of the newly spawned process. `setgid: int?` Sets the gid of the newly spawn process.

**Returns** \
`int` - The pid of the spawned process.

> ### uselib(path: string): any

Loads library at the given `path`.

**Arguments** \
`path: string` - The path to the library.

**Returns**  \
`any` - The return value of the loaded library.