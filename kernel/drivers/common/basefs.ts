import { BiMap } from "../../common/bimap";
import { Inode, create_inode, get_inode_file_type } from "../../vfs/inode/init";
import { Driver } from "../driver";
import { Error } from "../../common/error";
import { join } from "../../common/paths";

export abstract class BaseFS extends Driver {
	inodes: Inode[] = [];
	inode_path_map: BiMap<string, integer> = new BiMap<string, integer>();
	inode_id: integer = 0;

	mount(path: Path): Inode {
		let inode = create_inode(this.inode_id, InodeModeFlags.TYPE_DIR, 0, 0);
		this.inode_id += 1;
		this.inodes[inode.id] = inode;
		this.inode_path_map.set(path, inode.id);
		return inode;
	}

	unmount(path: Path): void {
		let id = this.inode_path_map.get(path);
		if (id !== undefined) {
			delete this.inodes[id];
			this.inode_path_map.delete(path);
		}
	}

	read_dir(inode: Inode): string[] {
		if (!get_inode_file_type(inode, InodeModeFlags.TYPE_DIR)) {
			throw new Error("ENOTDIR", tostring(inode.id));
		}

		let inode_path = this.inode_path_map.getKey(inode.id);

		let prefix = inode_path === "/" ? "/" : inode_path + "/";
		let entries = [];
		for (const [path, _] of this.inode_path_map.entries()) {
			if (string.sub(path, 1, prefix.length) === prefix) {
				let name = string.sub(path, prefix.length + 1);
				// Destructure string.find to a single value: used directly under
				// `!`, tstl wraps the multi-return in an always-truthy table, so
				// the "no slash" test would always fail and drop every child.
				let [slash] = string.find(name, "/", 1, true);
				if (name.length > 0 && slash === undefined) {
					entries.push(name);
				}
			}
		}

		return entries;
	}

	get_inode(path: Path): Inode | undefined {
		let id = this.inode_path_map.get(path);
		return id === undefined ? undefined : this.inodes[id];
	}

	lookup(dir_inode: Inode, name: string): Inode | undefined {
		let dir_path = this.inode_path_map.getKey(dir_inode.id);
		if (dir_path === undefined) { return undefined; }
		if (name === "..") {
			let parent_path = string.match(dir_path, "^(.*)/[^/]+$")[0];
			if (parent_path === undefined || parent_path === "") { parent_path = "/"; }
			return this.get_inode(parent_path);
		}
		return this.get_inode(join(dir_path, name));
	}

	create_file(parent_inode: Inode, name: string, type: InodeModeFlags): Inode {
		let parent_path = this.inode_path_map.getKey(parent_inode.id);
		if (parent_path === undefined) {
			throw new Error("ENOENT", name);
		}

		let inode = create_inode(this.inode_id, type, 0, 0);
		this.inode_id += 1;
		this.inodes[inode.id] = inode;

		this.inode_path_map.set(join(parent_path, name), inode.id);

		if (type === InodeModeFlags.TYPE_DIR) {
			parent_inode.links += 1;
		}

		return inode;
	}

	destroy_file(inode: Inode): void {
		inode.links -= 1;
		this.inode_path_map.deleteKey(inode.id);
		if (inode.links === 0 && inode.refs === 0) {
			delete this.inodes[inode.id];
			this.inode_path_map.deleteKey(inode.id);
		} else if (inode.links === 0) {
			// Open fds still reference this inode. Mark it unlinked so the last
      // fd to close will free it via _free_inode().
			inode.unlinked = true;
		}
		// links > 0 means other directory entries still point here (hard links).
    // The inode stays alive; only the path entry was removed.
	}

	free_inode(inode: Inode) {
		delete this.inodes[inode.id];
		this.inode_path_map.deleteKey(inode.id);
	}
}
