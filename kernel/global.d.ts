/// <reference path="../node_modules/lua-types/5.2.d.ts" />
/// <reference path="../node_modules/@typescript-to-lua/language-extensions/index.d.ts" />

type integer = number;
type UID = integer;
type Path = string;

type ErrorCode =
		| "ENOENT"
		| "EACCES"
		| "EBADF"
		| "EEXIST"
		| "EISDIR"
		| "ENOEXEC"
		| "ENOTEMPTY"
		| "ENOTDIR";

/** @noResolution */
declare module "common.error" {
	interface ErrorObject {
		code: string;
		message: string;
	}

	type ErrorCode =
		| "ENOENT"
		| "EACCES"
		| "EBADF"
		| "EEXIST"
		| "EISDIR"
		| "ENOEXEC"
		| "ENOTEMPTY"
		| "ENOTDIR";

	/** @noSelf */
	interface ErrorModule {
		readonly ENOENT: "ENOENT";
		readonly EACCES: "EACCES";
		readonly EBADF: "EBADF";
		readonly EEXIST: "EEXIST";
		readonly EISDIR: "EISDIR";
		readonly ENOEXEC: "ENOEXEC";
		readonly ENOTEMPTY: "ENOTEMPTY";
		readonly ENOTDIR: "ENOTDIR";

		err(code: ErrorCode, message: string): ErrorObject;
		throw(code: ErrorCode, message: string): never;
	}

	const Error: ErrorModule;

	export = Error;
}

/** @noResolution */
declare module "vfs.inode" {
	interface Inode {
		id: integer;
		links: integer;
		size: integer;
		refs: integer;
		unlinked: boolean;
		owner: integer;
		group: integer;
		mode: integer;
	}

	namespace Inode {
		// update file_type with inodemodeflags type
		function create(
			id: integer,
			file_type: InodeModeFlags,
			owner: integer,
			group: integer,
		): Inode;
		function get_perms(
			ind: Inode,
			rwe_mask: integer,
			uid: integer,
			gids: Array<integer>,
		): boolean;
		function get_file_type(ind: Inode, flag: integer): boolean;
	}

	export = Inode;
}

declare const enum FileDescriptorOpenFlags {
	// Open flags
	O_RDONLY    = 0x0000,
	O_WRONLY    = 0x0001,
	O_RDWR      = 0x0002,
	O_CREAT     = 0x0040,
	O_TRUNC     = 0x0200,
	O_APPEND    = 0x0400,
	O_NONBLOCK  = 0x0800,
	// IMPLEMENT O_NONBLOCK FOR BLOCKING/NONBLOCKING READ AND WRITE
	O_DIRECTORY = 0x10000, // Fail if path is not a directory; required to open a directory
	O_CLOEXEC   = 0x20000, // Close this fd automatically on exec()

	// Seek whence
	SEEK_SET = 0,
	SEEK_CUR = 1,
	SEEK_END = 2
}

declare const enum Termios {
	// lflag bits
	ISIG   = 0x0001, // signal generation (^C, ^Z)
	ICANON = 0x0002, // canonical (line-buffered) input
	ECHO   = 0x0008, // echo input characters
	ECHOE  = 0x0010, // echo erase as BS-SP-BS
	// iflag bits
	ICRNL  = 0x0100, // map CR to NL on input
	// oflag bits
	OPOST  = 0x0001, // enable output processing
	ONLCR  = 0x0004, // map NL to CR-NL on output
	// c_cc indices
	VINTR  = 1, // interrupt char (^C, byte 3)
	VERASE = 2, // erase char     (^H, byte 8)
	VKILL  = 3, // kill line      (^U, byte 21)
	VEOF   = 4, // end-of-file    (^D, byte 4)
}

declare const enum InodeModeFlags {
	TYPE_SCK = 0xc000, // Socket
	TYPE_SYM = 0xa000, // Symlink
	TYPE_REG = 0x8000, // Regular file
	TYPE_BLK = 0x6000, // Block device
	TYPE_DIR = 0x4000, // Directory
	TYPE_CHR = 0x2000, // Character device
	TYPE_PIP = 0x1000, // Pipe/FIFO
	// [ Special flags ]
	IS_SETUID = 0x0800, // Setuid
	IS_SETGID = 0x0400, // Setgid
	IS_STICKY = 0x0200, // Sticky
	// [ Permission flags ]
	OWNER_READ = 0x0100, // Owner Read
	OWNER_WRITE = 0x0080, // Owner Write
	OWNER_EXEC = 0x0040, // Owner Execute
	GROUP_READ = 0x0020, // Group Read
	GROUP_WRITE = 0x0010, // Group Write
	GROUP_EXEC = 0x0008, // Group Execute
	OTHER_READ = 0x0004, // Other Read
	OTHER_WRITE = 0x0002, // Other Write
	OTHER_EXEC = 0x0001, // Other Execute
	// [ Bitmasks for inode flags ]
	MASK_SPECIAL = 0x0e00, // Special bits (setuid, setgid, stick)
	MASK_OWNER = 0x01c0, // Owner perms
	MASK_GROUP = 0x0038, // Group perms
	MASK_OTHER = 0x0007, // Other perms
	MASK_READ = 0x0124, // Read perms
	MASK_WRITE = 0x0092, // Write perms
	MASK_EXEC = 0x0049, // Execute perms
	MASK_PERMS = 0x01ff, // All perms (excluding special bits)
	MASK_MODE = 0x0fff, // All perms (including special bits)
	MASK_TYPE = 0xf000, // File type
}

declare module "drivers.driver" {
	import type Inode from "vfs.inode";

	interface Driver {
		arch: unknown;
		"new"(arch: unknown): Driver;
		mount(path: string): Inode;
		unmount(path: string): void;
		get_inode(path: string): Inode;
		lookup(dir_inode: Inode, name: string): Inode | null;
		read_dir(inode: Inode): string[];
		create_file(parent_inode: Inode, name: string, type: InodeModeFlags): Inode;
		destroy_file(inode: Inode): void;
		read_file(inode: Inode, offset: integer, length: integer): unknown;
		write_file(inode: Inode, offset: integer, data: unknown): void;
		ioctl(inode: Inode, request: integer, arg: any): unknown;
	}

	const Driver: Driver;

	export = Driver;
}

/** @noResolution */
declare module "processes.process" {
	import type Inode from "vfs.inode";
	import type Credentials from "processes.credentials";

	interface Process {
		pid: integer;
		ppid: integer;
		cred: Credentials;
		capabilities: integer;
		fds: any[];
		current_directory: string;
		cwd_mount: import("./vfs/mount").Mount;
		cwd_inode: Inode;
		argv: LuaTable<string>;
		envp: LuaTable<string>;
		dead: boolean;
		exit_code: integer;
		coroutine: LuaThread;
		kernel: unknown;
		env: LuaTable;
	}

	const Process: Process;

	export = Process;
}

/** @noResolution */
declare module "processes.credentials" {
	interface Credentials {
		ruid: integer;
		euid: integer;
		suid: number;
		rgid: number;
		egid: number;
		sgid: number;
		supplementary_groups: LuaTable<integer>;
		get_gids(): integer[];
	}

	const Credentials: Credentials;

	export = Credentials;
}
