/** @noSelfInFile */
import { btest } from "../common/bitwise";
import { FileDescriptor } from "../vfs/fd/init";

export class FDTable {
	private fds: LuaTable<integer, FileDescriptor> = new LuaTable();

	get(n: integer): FileDescriptor {
		return this.fds.get(n);
	}

	set(n: integer, fd: FileDescriptor) {
		this.fds.set(n, fd);
	}

	close(n: integer) {
		let fd = this.fds.get(n);
		if (fd !== undefined) {
			fd.close();
			this.fds.delete(n);
		}
	}

	// close all fds that were opened with O_CLOEXEC. Called on exec().
	close_cloexec() {
		let to_close: integer[] = [];
		for (const [n, fd] of pairs(this.fds)) {
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
		while (this.fds.get(n) !== undefined) { n += 1; };
		this.fds.set(n, fd);
		return n;
	}

	inherit(fdtable: FDTable) {
		for (let i = 0; i < 3; i++) {
			this.set(i, fdtable.get(i))
		}
	}
}
