/** @noSelfInFile */

import { btest } from "../common/bitwise";
import { KError } from "../common/error";
import { Process } from "./process";

export interface ProcessInterface {
	exec(this: void, path: Path): void;
	spawn(this: void, path: Path, argv: LuaTable): integer;
	open(this: void, path: Path, flags: integer): integer;
	close(this: void, fd: integer): void;
	read(this: void, fd: integer, length: integer): string;
	write(this: void, fd: integer, data: string): integer;
	ioctl(this: void, fd: integer, request: any, arg: any): any;
	seek(this: void, fd: integer, offset: integer, whence: FileDescriptorOpenFlags): integer;
	getdents(this: void, fd: integer): LuaTable<integer, string>;
	openat(this: void, dirfd: integer, path: Path, flags: integer): integer;
	unlink(this: void, path: Path): void;
	mkdir(this: void, path: Path): void;
	rmdir(this: void, path: Path): void;
	read_dir(this: void, path: Path): void;
	getcwd(this: void, ): Path;
	chdir(this: void, path: Path): void;
	exit(this: void, code: integer): void;
	wait(this: void, pid: integer): unknown;
	require(this: void, mod_name: string): unknown;
}

export function create(process: Process): ProcessInterface {
	let vfs = process.kernel.vfs;
	let procman = process.kernel.procman;
	let loaded = new LuaTable<string, unknown>();

	return {
		exec(path) {
			process.exec(path);
			coroutine.yield();
		},

		spawn(path, argv) {
			return process.spawn(path, argv);
		},

		open(path, flags) {
			return process.open_fd(path, flags);
		},

		close(fd) {
			process.close_fd(fd);
		},

		read(fd, length) {
			let f = process.fds.get(fd);
			if (f === undefined) {
				throw new KError("EBADF", "invalid file descriptor " + tostring(fd));
			}
			if (!btest(f.flags, FileDescriptorOpenFlags.O_NONBLOCK)) {
				let data;
				while (data === undefined) {
					coroutine.yield();
					data = f.read(length);
				}
				return data;
			} else {
				return f.read(length);
			}
		},

		write(fd, data) {
			let f = process.fds.get(fd);
			if (f === undefined) {
				throw new KError("EBADF", "invalid file descriptor " + tostring(fd));
			}
			return f.write(data);
		},

		ioctl(fd, request, arg) {
			let f = process.fds.get(fd);
			if (f === undefined) {
				throw new KError("EBADF", "invalid file descriptor " + tostring(fd));
			}
			f.ioctl(request, arg);
		},

		seek(fd, offset, whence) {
			let f = process.fds.get(fd);
			if (f === undefined) {
				throw new KError("EBADF", "invalid file descriptor " + tostring(fd));
			}
			return f.seek(offset, whence);
		},

		getdents(fd) {
			let f = process.fds.get(fd);
			if (f === undefined) {
				throw new KError("EBADF", "invalid file descriptor " + tostring(fd));
			}
			if (!btest(f.flags, FileDescriptorOpenFlags.O_DIRECTORY)) {
				throw new KError("ENOTDIR", "fd " + tostring(fd) + " is not a directory fd");
			}
			let entries = f.driver.read_dir(f.inode);
			if (!entries.has(".")) {
				table.insert(entries, ".");
			}
			if (!entries.has("..")) {
				table.insert(entries, "..");
			}

			return entries;
		},

		openat(dirfd, path, flags) {
			let dir_f = process.fds.get(dirfd);
			if (dir_f === undefined) {
				throw new KError("EBADF", "invalid file descriptor " + tostring(dirfd));
			}
			if (!btest(dir_f.flags, FileDescriptorOpenFlags.O_DIRECTORY)) {
				throw new KError("ENOTDIR", "fd " + tostring(dirfd) + " is not a directory fd");
			}
			return process.open_fd(path, flags, dir_f.mount, dir_f.inode);
		},

		unlink(path) {
			vfs.unlink(process, path);
		},

		mkdir(path) {
			vfs.mkdir(process, path);
		},

		rmdir(path) {
			vfs.rmdir(process, path);
		},

		read_dir(path) {
			return vfs.read_dir(process, path);
		},

		getcwd() {
			return process.current_directory;
		},

		chdir(path) {
			process.chdir(path);
		},

		exit(code) {
			process.dead = true;
			process.exit_code = code || 0;
			coroutine.yield();
		},

		wait(pid) {
			let proc = procman.get_process(pid);
			while (proc !== undefined && !proc.dead) {
				coroutine.yield();
				proc = procman.get_process(pid);
			}
			return proc && proc.exit_code;
		},

		require(mod_name) {
			let mod = loaded.get(mod_name);
			if (mod !== undefined) {
				return mod;
			}

			let base = "/lib/" + string.gsub(mod_name, "%.", "/");
			let candidates: string[] = [base + ".lua", base + "/init.lua"];

			let code, found_path;
			for (const path of candidates) {
				let [mount, inode] = vfs.namei(path);
				if (inode !== undefined && mount !== undefined) {
					code = mount.driver.read_file(inode, 0, inode.size);
					found_path = path;
					break;
				}
			}

			if (code === undefined) {
				throw "module '" + mod_name + "' not found";
			}

			let [chunk, err] = load(code, "@" + found_path, "t", process.env);
			if (!chunk) {
				error("error loading module '" + mod_name + "': " + err);
			}

			let result = chunk();
			loaded.set(mod_name, result !== undefined ? result : true);
			return loaded.get(mod_name);
		}
	}
}
