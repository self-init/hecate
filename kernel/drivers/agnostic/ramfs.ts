import { BaseFS } from "../common/basefs";

export class RamFS extends BaseFS {
	data = new Map<integer, string>();

	read_file(inode: Inode, offset: integer, length: integer): string {
		let contents = this.data.get(inode.id) || "";
		return string.sub(contents, offset + 1, offset + length);
	}

	write_file(inode: Inode, offset: integer, data: string) {
		let contents = this.data.get(inode.id) || "";
		let prefix = string.sub(contents, 1, offset);
		if (prefix.length < offset) {
			prefix += string.rep("\0", offset - prefix.length);
		}
		let suffix = string.sub(contents, offset + data.length + 1);
		let new_data = prefix + data + suffix;
		this.data.set(inode.id, new_data);
		inode.size = new_data.length;
		return data.length;
	}

	ioctl(inode: Inode, request: integer, arg: any): unknown {
		return;
	}

	free_inode(inode: Inode) {
		super.free_inode(inode);
		this.data.delete(inode.id);
	}
}
