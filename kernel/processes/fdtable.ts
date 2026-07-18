/** @noSelfInFile */
import { btest } from "../common/bitwise";
import { FileDescriptor } from "../vfs/fd/init";

class FDTable {
	private fds: FileDescriptor[] = [];

	get(n: integer): FileDescriptor {
		return this.fds[n];
	}

	set(n: integer, fd: FileDescriptor) {
		this.fds[n] = fd;
	}

	close(n: integer) {
		let fd = this.fds[n];
		if (fd !== null) {
			fd.close();
			delete this.fds[n];
		}
	}

	// close all fds that were opened with O_CLOEXEC. Called on exec().
	close_cloexec() {
		let to_close: integer[] = [];
		for (const [n, fd] of this.fds.entries()) {
			if (btest(fd.flags, FileDescriptorOpenFlags.O_CLOEXEC)) {
				to_close.push(n);
			}
		}
		for (const n of to_close) {
			this.close(n);
		}
	}

	insert(fd: FileDescriptor): integer {
		let n = 3;
		while (this.fds[n] !== null) { n += 1; };
		this.fds[n] = fd;
		return n;
	}

	inherit(fdtable: FDTable) {
		for (let i = 0; i < 2; i++) {
			this.set(i, fdtable.get(i))
		}
	}
}

export function create(): FDTable {
	return new FDTable();
}
