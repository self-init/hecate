import * as Bitwise from "../common/bitwise";
import { band, freeze } from "../common/bitwise";
import { Error } from "../common/error";
import { resolve } from "../common/paths";
import { Kernel } from "../kernel";
import { FileDescriptor } from "../vfs/fd/init";
import { get_inode_file_type } from "../vfs/inode/init";
import { Mount } from "../vfs/mount";
import { Credentials } from "./credentials";
import { FDTable } from "./fdtable";
import { create as create_interface } from "./interface";

// const enums have no runtime table, so we cannot iterate the flag names the
// way the Lua version did with pairs(FileDescriptorOpenFlags). List them here
// explicitly to expose them as globals in the process sandbox.
const OPEN_FLAG_GLOBALS = {
	O_RDONLY: FileDescriptorOpenFlags.O_RDONLY,
	O_WRONLY: FileDescriptorOpenFlags.O_WRONLY,
	O_RDWR: FileDescriptorOpenFlags.O_RDWR,
	O_CREAT: FileDescriptorOpenFlags.O_CREAT,
	O_TRUNC: FileDescriptorOpenFlags.O_TRUNC,
	O_APPEND: FileDescriptorOpenFlags.O_APPEND,
	O_NONBLOCK: FileDescriptorOpenFlags.O_NONBLOCK,
	O_DIRECTORY: FileDescriptorOpenFlags.O_DIRECTORY,
	O_CLOEXEC: FileDescriptorOpenFlags.O_CLOEXEC,
	SEEK_SET: FileDescriptorOpenFlags.SEEK_SET,
	SEEK_CUR: FileDescriptorOpenFlags.SEEK_CUR,
	SEEK_END: FileDescriptorOpenFlags.SEEK_END,
};

export class Process {
	pid: integer = 0;
	ppid: integer = 0;
	cred: Credentials = new Credentials();
	fds: FDTable = new FDTable();
	current_directory: Path = "/";
	cwd_mount: Mount;
	cwd_inode: Inode;
	argv;
	envp = {};
	dead: boolean = false;
	exit_code: integer | undefined;
	coroutine: LuaThread | undefined;
	kernel: Kernel;
	env: LuaTable<string, unknown> | undefined;

	constructor(kernel: Kernel, path: Path, argv?: unknown) {
		this.cwd_mount = kernel.vfs.root_mount!;
		this.cwd_inode = kernel.vfs.root_mount?.root_inode!;
		this.argv = argv || {};
		this.kernel = kernel;

		this.open_tty_fds();
		this.exec(path);
	}

	private open_tty_fds() {
		let [mount, inode] = this.kernel.vfs.namei("/dev/tty");
		for (let n = 0; n < 2; n++) {
			this.fds.set(n, new FileDescriptor(mount, inode!, "/dev/tty", FileDescriptorOpenFlags.O_RDWR));
		}
	}

	open_fd(path: Path, flags: integer, base_mount?: Mount, base_inode?: Inode) {
		let vfs = this.kernel.vfs;
		let cwd_mount = base_mount || this.cwd_mount;
		let cwd_inode = base_inode || this.cwd_inode;
		let [mount, inode] = vfs.namei(path, this.cred, cwd_mount, cwd_inode);

		if (inode === undefined || inode === null) {
			if (band(flags, FileDescriptorOpenFlags.O_CREAT) !== 0) {
				let [name] = string.match(path, "[^/]+$") || path;
				let [parent_path] = string.match(path, "^(.+)/[^/]+$") || (string.sub(path, 1, 1) === "/" ? "/" : ".");
				let [parent_mount, parent_inode] = vfs.namei(parent_path, this.cred, cwd_mount, cwd_inode);
				if (parent_inode === undefined || parent_inode === null) {
					throw new Error("ENOENT", path);
				}
				vfs.check_inode_perm(this.cred, parent_inode, InodeModeFlags.MASK_WRITE, path);
				vfs.check_inode_perm(this.cred, parent_inode, InodeModeFlags.MASK_EXEC, path);
				inode = parent_mount.driver.create_file(parent_inode, name, InodeModeFlags.TYPE_REG);
				mount = parent_mount;
			} else {
				throw new Error("ENOENT", path);
			}
		}

		let is_dir = get_inode_file_type(inode, InodeModeFlags.TYPE_DIR);
		if (is_dir && band(flags, FileDescriptorOpenFlags.O_DIRECTORY) === 0) {
			throw new Error("EISDIR", path);
		}
		if (!is_dir && band(flags, FileDescriptorOpenFlags.O_DIRECTORY) !== 0) {
			throw new Error("ENOTDIR", path);
		}

		let accmode = band(flags, 0x0003);
		if (accmode !== FileDescriptorOpenFlags.O_WRONLY) {
			vfs.check_inode_perm(this.cred, inode, InodeModeFlags.MASK_READ, path);
		}
		if (accmode !== FileDescriptorOpenFlags.O_RDONLY) {
			vfs.check_inode_perm(this.cred, inode, InodeModeFlags.MASK_WRITE, path);
		}

		if (band(flags, FileDescriptorOpenFlags.O_TRUNC) !== 0) {
			mount.driver.write_file(inode, 0, "");
			inode.size = 0;
		}

		return this.fds.insert(new FileDescriptor(mount, inode, path, flags));
	}

	close_fd(n: integer) {
		this.fds.close(n);
	}

	// Builds the sandboxed global environment for a process.
	// Exposes safe Lua builtins and the ProcessInterface syscalls.
	make_env() {
		let env = new LuaTable<string, unknown>();

		// Safe Lua standard library
		env.set("math", math);
		env.set("string", string);
		env.set("table", table);
		env.set("ipairs", ipairs);
		env.set("pairs", pairs);
		env.set("next", next);
		env.set("type", type);
		env.set("tostring", tostring);
		env.set("tonumber", tonumber);
		env.set("select", select);
		env.set("error", error);
		env.set("assert", assert);
		env.set("pcall", pcall);
		env.set("xpcall", xpcall);
		env.set("setmetatable", setmetatable);
		env.set("getmetatable", getmetatable);
		env.set("rawget", rawget);
		env.set("rawset", rawset);
		env.set("rawequal", rawequal);
		env.set("rawlen", rawlen);
		env.set("bitwise", freeze(Bitwise));

		// File descriptor open flags and seek constants
		for (const [k, v] of pairs(OPEN_FLAG_GLOBALS)) {
			env.set(k, v);
		}
		env.set("argv", this.argv);
		this.env = env;

		// Merge ProcessInterface functions in as globals
		for (const [k, v] of pairs(create_interface(this))) {
			env.set(k, v);
		}

		env.set("_ENV", env);
		return env;
	}

	exec(path: Path) {
		let vfs = this.kernel.vfs;
		let [mount, inode] = vfs.namei(path, this.cred, this.cwd_mount, this.cwd_inode);

		if (inode === undefined || inode === null) {
			throw new Error("ENOENT", path);
		}

		if (!get_inode_file_type(inode, InodeModeFlags.TYPE_REG)) {
			throw new Error("ENOEXEC", path);
		}

		vfs.check_inode_perm(this.cred, inode, InodeModeFlags.MASK_EXEC, path);

		let code = mount.driver.read_file(inode, 0, inode.size);

		let [chunk, err] = load(code, "@" + path, "t", this.make_env());
		if (chunk === undefined) {
			throw new Error("ENOEXEC", path);
		}

		this.coroutine = coroutine.create(chunk);
		this.fds.close_cloexec();
	}

	kill() {

	}

	chdir(path: Path) {
		let vfs = this.kernel.vfs;
		let [mount, inode] = vfs.namei(path, this.cred, this.cwd_mount, this.cwd_inode);

		if (inode === undefined || inode === null) {
			throw new Error("ENOENT", path);
		}

		if (!get_inode_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			throw new Error("ENOTDIR", path);
		}

		vfs.check_inode_perm(this.cred, inode, InodeModeFlags.MASK_EXEC, path);

		this.cwd_mount = mount;
		this.cwd_inode = inode;
		this.current_directory = resolve(path, this.current_directory);
	}
}
