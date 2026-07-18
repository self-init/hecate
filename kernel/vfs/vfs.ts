import { Error } from "../common/error";
import type { Credentials } from "../processes/credentials";
import type { Inode } from "./inode/init";
import { get_inode_perms, get_inode_file_type } from "./inode/init";
import { Mount, MountParentInfo } from "./mount";
import * as Process from "processes.process";
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
		const mountpoint_inode: Inode = mount.parent.mountpoint;
		const parent_mount: Mount = mount.parent.mount;

		if (mountpoint_inode.id === parent_mount.root_inode.id) {
			return $multi(parent_mount, parent_mount.root_inode);
		}

		const parent_inode: Inode | null = parent_mount.driver.lookup(mountpoint_inode, "..");
		return $multi(parent_mount, parent_inode || parent_mount.root_inode)
	}

	namei(path: Path, cred?: Credentials, cwd_mount?: Mount, cwd_inode?: Inode): LuaMultiReturn<[Mount, Inode | null]> {
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

			const child_mount: Mount = mount.children[next_inode.id];
			mount = child_mount || mount;
			inode = child_mount !== null ? child_mount.root_inode : next_inode;
		}

		return $multi(mount, inode);
	}

	// Check permissions on an inode.
	// euid === 0 always passes
	// throws an error if no permission
	check_inode_perm(cred: Credentials, inode: Inode, mask: integer, path: Path) {
		if (cred.euid === 0) { return; }
		if (!get_inode_perms(inode, mask, cred.euid, cred.get_gids())) {
			throw new Error("EACCES", path);
		}
	}

	mount(driver: Driver, mount_path: Path): Inode {
		let root_inode: Inode = driver.mount(mount_path)

		if (mount_path === "/") {
			this.root_mount = new Mount(driver, root_inode);
		} else {
			let [parent_mount, mp_inode] = this.namei(mount_path);

			if (mp_inode === null) {
				throw new Error("ENOENT", mount_path);
			}
			let mp_info: MountParentInfo = { mount: parent_mount, mountpoint: mp_inode }
			let new_mount = new Mount(driver, root_inode, mp_info);
			parent_mount.children[mp_inode.id] = new_mount;
		}

		return root_inode;
	}

	unmount(mount_path: Path): void {
		if (mount_path === "/") {
			this.root_mount == null
		} else {
			let [parent_mount, mp_inode] = this.namei(mount_path);
			if (mp_inode && parent_mount.children[mp_inode.id]) {
				delete parent_mount.children[mp_inode.id];
			}
		}
	}

	private get_inode_or_error(path: Path, process: Process): LuaMultiReturn<[Mount, Inode]> {
		let [mount, inode] = this.namei(path, process.cred, process.cwd_mount, process.cwd_inode);
		if (inode === null) { throw new Error("ENOENT", path); }
		return $multi(mount, inode);
	}

	read_file(process: Process, path: Path, offset: integer, length: integer) {
		let [mount, inode] = this.get_inode_or_error(path, process);
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_READ, path);
		return mount.driver.read_file(inode, offset, length);
	}

	read_dir(process: Process, path: Path): string[] {
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

	write_file(process: Process, path: Path, offset: integer, data: unknown) {
		let [mount, inode] = this.get_inode_or_error(path, process);
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_WRITE, path);
		return mount.driver.write_file(inode, offset, data);
	}

	create_file(process: Process, parent_path: Path, name: string, type: InodeModeFlags) {
		let [mount, parent_inode] = this.get_inode_or_error(parent_path, process);
		if (get_inode_file_type(parent_inode, InodeModeFlags.TYPE_DIR) === null) {
			throw new Error("ENOTDIR", parent_path);
		}
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);
		return mount.driver.create_file(parent_inode, name, type);
	}

	unlink(process: Process, path: Path) {
		let [mount, inode] = this.get_inode_or_error(path, process);
		if (!get_inode_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			throw new Error("EISDIR", path);
		}
		let parent_path: Path = string.match(path, "^(.+)/[^/]+$")[0] || string.sub(path, 1, 1);
		let [_, parent_inode] = this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode);
		if (parent_inode) {
			this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
			this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);
		}
		mount.driver.destroy_file(inode);
	}

	mkdir(process: Process, path: Path): unknown {
		let name: string = string.match(path, "[^/]+$")[0] || (string.sub(path, 1, 1) === "/" ? "/" : ".");
		let parent_path: Path = string.match(path, "^(.+)/[^/]+$")[0] || (string.sub(path, 1, 1) === "/" ? "/" : ".");
		let [mount, parent_inode] = this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode);
		if (parent_inode === null) { throw new Error("ENOENT", parent_path); }
		if (!get_inode_file_type(parent_inode, InodeModeFlags.TYPE_DIR)) {
			throw new Error("EISDIR", parent_path);
		}
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);

		let [_, existing] = this.namei(path, process.cred, process.cwd_mount, process.cwd_inode);
		if (existing !== null) { throw new Error("EEXIST", path); }
		return mount.driver.create_file(parent_inode, name, InodeModeFlags.TYPE_DIR);
	}

	rmdir(process: Process, path: Path): void {
		let [mount, inode] = this.get_inode_or_error(path, process);
		if (!get_inode_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			throw new Error("ENOTDIR", path);
		}
		let entries = mount.driver.read_dir(inode);
		if (entries !== null && entries.length > 0) {
			throw new Error("ENOTEMPTY", path);
		}
		let parent_path: Path = string.match(path, "^(.+)/[^/]+$")[0] || (string.sub(path, 1, 1) === "/" ? "/" : ".");
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
