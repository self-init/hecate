import { Inode } from "../../vfs/inode/init";
import { BaseChrDev } from "../common/basechrdev";
import type { CCArch } from "../../arch/cc/arch";

export class Kbd extends BaseChrDev<CCArch> {
	event_queue: string[] = [];

	push_event(event: string) {
		this.event_queue.push(event);
	}

	read_file(inode: Inode, offset: integer, length: integer): string {
		return this.arch.kbd_queue.shift();
	}

	write_file(inode: Inode, offset: integer, data: unknown): integer {
		return 0;
	}

	ioctl(inode: Inode, request: integer, arg: any): unknown {
		return;
	}
}
