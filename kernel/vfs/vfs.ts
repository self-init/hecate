import * as Error from "common.error";
import * as Inode from "vfs.inode";
import * as Mount from "vfs.mount";
import * as Process from "processes.process";
import * as Credentials from "processes.credentials";
import * as Driver from "drivers.driver";

export class Vfs {
	root_mount: Mount | null;
	mounts: LuaTable<integer, Mount>;

	constructor() {
		this.root_mount = null;
		this.mounts = new LuaTable()
	}

	private resolve_dotdot(mount: Mount, inode: Inode): LuaMultiReturn<[Mount, Inode]> {
		// Not at the root of this mount: plain parent lookup.
		if (inode.id !== mount.root_inode.id) {
			const parent = mount.driver.lookup(inode, "..");
			return $multi(mount, parent || inode);
		}

		// At the root of this mount, but it's the global root: nowhere to go.
		if (!mount.parent) {
			return $multi(mount, inode);
		}

		// Cross upward to parent mount
		const mountpoint_inode: Inode = mount.mountpoint_inode;
		const parent_mount: Mount = mount.parent;

		if (mountpoint_inode.id === parent_mount.root_inode.id) {
			return $multi(parent_mount, parent_mount.root_inode);
		}

		const parent_inode: Inode | null = parent_mount.driver.lookup(mountpoint_inode, "..");
		return $multi(parent_mount, parent_inode || parent_mount.root_inode)
	}

	namei(path: string, cred?: Credentials, cwd_mount?: Mount, cwd_inode?: Inode): LuaMultiReturn<[Mount, Inode | null]> {
		if (this.root_mount === null) { error("Attempted to get file with no root mount", 2); }
		const is_absolute = string.sub(path, 1, 1) === "/";
		let mount: Mount = is_absolute ? this.root_mount : (cwd_mount || this.root_mount);
		let inode: Inode = is_absolute ? this.root_mount?.root_inode : (cwd_inode || this.root_mount?.root_inode);

		for (const [component] of string.gmatch(path, "([^/]+)")) {
			if (component === ".") continue;

			if (component === "..") {
				[mount, inode] = this.resolve_dotdot(mount, inode);
				continue;
			}

			if (cred !== undefined) {
				this.check_inode_perm(cred, inode, InodeModeFlags.MASK_EXEC, component);
			}

			const next_inode: Inode | null = mount.driver.lookup(inode, component);
			if (next_inode === null) {
				return $multi(mount, null); // not found; return mount ctx so callers can create files
			}

			const child_mount: Mount = mount.children.get(next_inode.id);
			mount = child_mount || mount;
			inode = child_mount !== null ? child_mount.root_inode : next_inode;
		}

		return $multi(mount, inode);
	}

	// Check permissions on an inode.
	// euid === 0 always passes
	// throws an error if no permission
	check_inode_perm(cred: Credentials, inode: Inode, mask: integer, path: string) {
		if (cred.euid === 0) { return; }
		if (!Inode.get_perms(inode, mask, cred.euid, cred.get_gids())) {
			Error.throw(Error.EACCES, path);
		}
	}

	mount(driver: Driver, mount_path: string): Inode {
		let root_inode: Inode = driver.mount(mount_path)

		if (mount_path === "/") {
			this.root_mount = Mount.new(driver, null, null, root_inode);
		} else {
			let [parent_mount, mp_inode] = this.namei(mount_path);

			if (mp_inode === null) {
				Error.throw(Error.ENOENT, mount_path);
			}

			let new_mount = Mount.new(driver, parent_mount, mp_inode, root_inode);
			parent_mount.children.set(mp_inode.id, new_mount);
		}

		return root_inode;
	}

	unmount(mount_path: string): void {
		if (mount_path === "/") {
			this.root_mount == null
		} else {
			let [parent_mount, mp_inode] = this.namei(mount_path);
			if (mp_inode && parent_mount.children.get(mp_inode.id)) {
				parent_mount.children.delete(mp_inode.id);
			}
		}
	}

	private get_inode_or_error(path: string, process: Process): LuaMultiReturn<[Mount, Inode]> {
		let [mount, inode] = this.namei(path, process.cred, process.cwd_mount, process.cwd_inode);
		if (inode === null) { Error.throw(Error.ENOENT, path); }
		return $multi(mount, inode);
	}

	read_file(process: Process, path: string, offset: integer, length: integer) {
		let [mount, inode] = this.get_inode_or_error(path, process);
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_READ, path);
		return mount.driver.read_file(inode, offset, length);
	}

	read_dir(process: Process, path: string): string[] {
		let [mount, inode] = this.get_inode_or_error(path, process);
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_READ, path);
		let entries = mount.driver.read_dir(inode);

		if (!entries.includes(".")) {
			entries.push(".");
		}
		if (!entries.includes("..")) {
			entries.push("..");
		}

		return entries;
	}

	write_file(process: Process, path: string, offset: integer, data: unknown) {
		let [mount, inode] = this.get_inode_or_error(path, process);
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_WRITE, path);
		return mount.driver.write_file(inode, offset, data);
	}

	create_file(process: Process, parent_path: string, name: string, type: InodeModeFlags) {
		let [mount, parent_inode] = this.get_inode_or_error(parent_path, process);
		if (Inode.get_file_type(parent_inode, InodeModeFlags.TYPE_DIR) === null) {
			Error.throw(Error.ENOTDIR, parent_path);
		}
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);
		return mount.driver.create_file(parent_inode, name, type);
	}

	unlink(process: Process, path: string) {
		let [mount, inode] = this.get_inode_or_error(path, process);
		if (!Inode.get_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			Error.throw(Error.EISDIR, path);
		}
		let parent_path: string = string.match(path, "^(.+)/[^/]+$")[0] || string.sub(path, 1, 1);
		let [_, parent_inode] = this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode);
		if (parent_inode) {
			this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
			this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);
		}
		mount.driver.destroy_file(inode);
	}

	mkdir(process: Process, path: string): unknown {
		let name = string.match(path, "[^/]+$")[0] || (string.sub(path, 1, 1) === "/" ? "/" : ".");
		let parent_path: string = string.match(path, "^(.+)/[^/]+$")[0] || (string.sub(path, 1, 1) === "/" ? "/" : ".");
		let [mount, parent_inode] = this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode);
		if (parent_inode === null) { Error.throw(Error.ENOENT, parent_path); }
		if (!Inode.get_file_type(parent_inode, InodeModeFlags.TYPE_DIR)) {
			Error.throw(Error.EISDIR, parent_path);
		}
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);

		let [_, existing] = this.namei(path, process.cred, process.cwd_mount, process.cwd_inode);
		if (existing !== null) { Error.throw(Error.EEXIST, path); }
		return mount.driver.create_file(parent_inode, name, InodeModeFlags.TYPE_DIR);
	}

	rmdir(process: Process, path: string): void {
		let [mount, inode] = this.get_inode_or_error(path, process);
		if (!Inode.get_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			Error.throw(Error.ENOTDIR, path);
		}
		let entries = mount.driver.read_dir(inode);
		if (entries !== null && entries.length > 0) {
			Error.throw(Error.ENOTEMPTY, path);
		}
		let parent_path: string = string.match(path, "^(.+)/[^/]+$")[0] || (string.sub(path, 1, 1) === "/" ? "/" : ".");
		let [_, parent_inode] = this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode);
		if (parent_inode !== null) {
			this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
			this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);

			parent_inode.links -= 1;
		}
		mount.driver.destroy_file(inode);
	}
}

export function create(): Vfs {
	return new Vfs();
}
