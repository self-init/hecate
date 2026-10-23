import { err, isErr, isOk, KError, ok, Result, success, unwrap } from "../common/error";
import { basename, dirname } from "../common/paths";
import type { Credentials } from "../processes/credentials";
import type { Inode } from "./inode/init";
import { get_inode_perms, get_inode_file_type } from "./inode/init";
import { Mount, MountParentInfo } from "./mount";
import type { Process } from "../processes/process";
import { Driver } from "../drivers/driver";

export class Vfs {
	root_mount: Mount | undefined;
	mounts: LuaTable<integer, Mount>;

	constructor() {
		this.root_mount = undefined;
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

		const parent_inode: Inode | undefined = parent_mount.driver.lookup(mountpoint_inode, "..");
		return $multi(parent_mount, parent_inode || parent_mount.root_inode)
	}

	namei(path: Path, cred?: Credentials, cwd_mount?: Mount, cwd_inode?: Inode): Result<[Mount, Inode]> {
		if (this.root_mount === undefined) { return err("EIO", "Attempted to get file with no root mount"); }
		const is_absolute = string.sub(path, 1, 1) === "/";
		let mount: Mount = is_absolute ? this.root_mount : (cwd_mount || this.root_mount);
		let inode: Inode = is_absolute ? this.root_mount?.root_inode : (cwd_inode || this.root_mount?.root_inode);

		for (const [component] of string.gmatch(path, "([^/]+)")) {
			if (component === ".") continue;

			if (component === "..") {
				[mount, inode] = this.resolve_dotdot(mount, inode);
				continue;
			}

			if (cred !== undefined && !this.has_inode_perm(cred, inode, InodeModeFlags.MASK_EXEC)) {
				return err("EACCES", path);
			}

			const next_inode: Inode | undefined = mount.driver.lookup(inode, component);
			if (next_inode === undefined) {
				return err("ENOENT", path);
			}

			const child_mount: Mount = mount.children[next_inode.id];
			mount = child_mount || mount;
			inode = child_mount !== undefined ? child_mount.root_inode : next_inode;
		}

		return ok([mount, inode]);
	}

	// Check permissions on an inode.
	// euid === 0 always passes
	private has_inode_perm(cred: Credentials, inode: Inode, mask: integer): boolean {
		if (cred.euid === 0) { return true; }
		return get_inode_perms(inode, mask, cred.euid, cred.get_gids());
	}

	// throws an error if no permission
	check_inode_perm(cred: Credentials, inode: Inode, mask: integer, path: Path) {
		if (!this.has_inode_perm(cred, inode, mask)) {
			throw new KError("EACCES", path);
		}
	}

	mount(driver: Driver, mount_path: Path): Inode {
		let root_inode: Inode = driver.mount(mount_path)

		if (mount_path === "/") {
			this.root_mount = new Mount(driver, root_inode);
		} else {
			let [parent_mount, mp_inode] = unwrap(this.namei(mount_path));
			let mp_info: MountParentInfo = { mount: parent_mount, mountpoint: mp_inode }
			let new_mount = new Mount(driver, root_inode, mp_info);
			parent_mount.children[mp_inode.id] = new_mount;
		}

		return root_inode;
	}

	unmount(mount_path: Path): void {
		if (mount_path === "/") {
			this.root_mount = undefined;
		} else {
			let r = this.namei(mount_path);
			if (!r.ok) { return; }
			let [parent_mount, mp_inode] = r.value;
			if (parent_mount.children[mp_inode.id]) {
				delete parent_mount.children[mp_inode.id];
			}
		}
	}

	read_file(process: Process, path: Path, offset: integer, length: integer) {
		let [mount, inode] = unwrap(this.namei(path, process.cred, process.cwd_mount, process.cwd_inode));
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_READ, path);
		return mount.driver.read_file(inode, offset, length);
	}

	read_dir(process: Process, path: Path): Result<string[]> {
		let r = this.namei(path, process.cred, process.cwd_mount, process.cwd_inode);
		if (!r.ok) return r;
		let [mount, inode] = r.value;
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_READ, path);
		let dir_result = mount.driver.read_dir(inode);

		if (isErr(dir_result)) return dir_result;
		let entries = unwrap(dir_result);

		if (!entries.includes(".")) entries.push(".");
		if (!entries.includes("..")) entries.push("..");

		return ok(entries);
	}

	write_file(process: Process, path: Path, offset: integer, data: string) {
		let [mount, inode] = unwrap(this.namei(path, process.cred, process.cwd_mount, process.cwd_inode));
		this.check_inode_perm(process.cred, inode, InodeModeFlags.MASK_WRITE, path);
		return mount.driver.write_file(inode, offset, data);
	}

	create_file(process: Process, parent_path: Path, name: string, type: InodeModeFlags) {
		let [mount, parent_inode] = unwrap(this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode));
		if (!get_inode_file_type(parent_inode, InodeModeFlags.TYPE_DIR)) {
			throw new KError("ENOTDIR", parent_path);
		}
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);
		return mount.driver.create_file(parent_inode, name, type);
	}

	unlink(process: Process, path: Path) {
		let [mount, inode] = unwrap(this.namei(path, process.cred, process.cwd_mount, process.cwd_inode));
		if (get_inode_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			throw new KError("EISDIR", path);
		}
		let parent_path = dirname(path);
		let [_, parent_inode] = unwrap(this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode));
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);
		mount.driver.destroy_file(inode);
	}

	mkdir(process: Process, path: Path): unknown {
		let name = basename(path);
		let parent_path = dirname(path);
		let [mount, parent_inode] = unwrap(this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode));
		if (!get_inode_file_type(parent_inode, InodeModeFlags.TYPE_DIR)) {
			throw new KError("ENOTDIR", parent_path);
		}
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);

		let existing = this.namei(path, process.cred, process.cwd_mount, process.cwd_inode);
		if (existing.ok) { throw new KError("EEXIST", path); }
		if (existing.error.code !== "ENOENT") { throw existing.error; }
		return mount.driver.create_file(parent_inode, name, InodeModeFlags.TYPE_DIR);
	}

	rmdir(process: Process, path: Path): Result<void> {
		let r = this.namei(path, process.cred, process.cwd_mount, process.cwd_inode);
		if (!r.ok) return r;
		let [mount, inode] = r.value;
		if (!get_inode_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			throw new KError("ENOTDIR", path);
		}
		let dir_result = mount.driver.read_dir(inode);
		if (isOk(dir_result) && unwrap(dir_result).length > 0) {
			return err("ENOTEMPTY", path);
		}
		let parent_path = dirname(path);
		let parent_r = this.namei(parent_path, process.cred, process.cwd_mount, process.cwd_inode);
		if (!parent_r.ok) return parent_r;
		let [_, parent_inode] = parent_r.value;
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_WRITE, parent_path);
		this.check_inode_perm(process.cred, parent_inode, InodeModeFlags.MASK_EXEC, parent_path);

		parent_inode.links -= 1;
		mount.driver.destroy_file(inode);

		return success();
	}
}
