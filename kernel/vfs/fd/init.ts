/** @noSelfInFile */

import { Mount } from "../mount";
import { band, btest } from "../../common/bitwise";
import type { Inode } from "../inode/init";
import { KError } from "../../common/error"

export class FileDescriptor {
	mount: Mount;
	driver: any;
	inode: Inode;
	path: Path;
	offset: integer;
	flags: integer;

	constructor(mount: Mount, inode: Inode, path: Path, flags: integer) {
		this.mount = mount;
		this.driver = mount.driver;
		this.inode = inode;
		this.path = path;
		this.flags = flags;
		this.offset = band(flags, FileDescriptorOpenFlags.O_APPEND) !== 0 ? inode.size : 0;

		inode.refs += 1;
	}

	close() {
		this.inode.refs -= 1;
		if (this.inode.refs === 0 && this.inode.unlinked) {
			this.driver._free_inode(this.inode);
		}
	}

	read(length: integer) {
		if (btest(this.flags, FileDescriptorOpenFlags.O_DIRECTORY)) {
			throw new KError("EISDIR", this.path);
		}
		let data = this.driver.read_file(this.inode, this.offset, length);
		if (data !== undefined) {
			let n: integer = type(data) === "string" ? (data as string).length : 0;
			this.offset += n;
		}
		return data;
	}

	write(data: any): integer {
		if (btest(this.flags, FileDescriptorOpenFlags.O_DIRECTORY)) {
			throw new KError("EISDIR", this.path);
		}
		if (band(this.flags, FileDescriptorOpenFlags.O_APPEND) !== 0) {
			this.offset = this.inode.size;
		}
		let n: integer = this.driver.write_file(this.inode, this.offset, data);
		this.offset = this.offset + (n || (type(data) === "string" ? (data as string).length : 0))
		return n;
	}

	ioctl(request: integer, arg: any): any {
		return this.driver.ioctl(this.inode, request, arg);
	}

	seek(offset: integer, whence: FileDescriptorOpenFlags) {
		switch (whence) {
			case FileDescriptorOpenFlags.SEEK_SET:
				this.offset = offset;
				break;
			case FileDescriptorOpenFlags.SEEK_CUR:
				this.offset += offset;
				break;
			case FileDescriptorOpenFlags.SEEK_END:
				this.offset = this.inode.size + offset;
				break;
		}
		if (this.offset < 0) { this.offset = 0; }
		return this.offset;
	}
}
