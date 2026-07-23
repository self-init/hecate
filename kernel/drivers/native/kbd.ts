import { Inode } from "../../vfs/inode/init";
import { BaseChrDev } from "../common/basechrdev";

export class Kbd extends BaseChrDev {
	event_queue: string[] = [];

	push_event(event: string) {
		this.event_queue.push(event);
	}

	read_file(inode: Inode, offset: integer, length: integer): string {
		return this.event_queue.shift() || "";
	}

	write_file(inode: Inode, offset: integer, data: string): integer {
		return 0;
	}

	ioctl(inode: Inode, request: integer, arg: any): unknown {
		return;
	}
}
