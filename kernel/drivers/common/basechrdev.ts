import { create_inode, Inode } from "../../vfs/inode/init";
import { Error } from "../../common/error";
import { Driver } from "../driver";

export abstract class BaseChrDev extends Driver {
	path: Path | undefined;
	inode: Inode | undefined;
	coroutine: LuaThread | undefined;

	mount(path: Path): Inode {
		this.path = path;
		this.inode = create_inode(
			0,
			InodeModeFlags.TYPE_CHR,
			0,
			0
		);
		return this.inode;
	}

	unmount(path: Path): void {
		this.path = undefined;
		this.inode = undefined;
	}

	read_dir(inode: Inode): string[] {
		throw new Error("ENOTDIR", this.path || "");
	}

	get_inode(path: Path): Inode | undefined {
		return this.inode;
	}

	create_file(parent_inode: Inode, name: string, type: InodeModeFlags): Inode {
		throw new Error("ENOTDIR", this.path || "");
	}

	destroy_file(inode: Inode): void {
		if (inode === this.inode) {
			delete this.inode;
		}
	}

	_free_inode(inode: Inode) {

	}

	lookup(dir_inode: Inode, name: string) {
		return undefined;
	}

	abstract read_file(inode: Inode, offset: integer, length: integer): string;
	abstract write_file(inode: Inode, offset: integer, data: unknown): integer;
	abstract ioctl(inode: Inode, request: integer, arg: any): unknown;
}
