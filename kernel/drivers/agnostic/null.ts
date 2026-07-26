import { BaseChrDev } from "../common/basechrdev";
import { Inode } from "../../vfs/inode/init";

export class Null extends BaseChrDev {
	read_file(inode: Inode, offset: integer, length: integer): string {
		return "";
	}

	write_file(inode: Inode, offset: integer, data: string): integer {
		return data.length;
	}

	ioctl(inode: Inode, request: integer, arg: any): unknown {
		return;
	}
}
