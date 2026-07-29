import { Null } from "../../drivers/agnostic/null";
import { Kbd } from "../../drivers/cc/kbd";
import { CCTty } from "../../drivers/cc/tty";
import { Kernel } from "../../kernel";
import { Arch } from "../arch";

const KEY_TO_CHAR = new Map<integer, char>([
	[keys.enter, "\n"],
	[keys.numPadEnter, "\n"],
	[keys.backspace, "\x08"],
])

export class CCArch implements Arch {
	kernel: Kernel | undefined;
	kbd_queue: any[] = [];
	events_listeners = [];
	tty = new CCTty(this);
	private timer_id: integer = 0;

	init(kernel: Kernel) {
		this.kernel = kernel;
		this.timer_id = os.startTimer(0.05);

		let [devfs_mount, devfs_root] = kernel.vfs.namei("/dev");
		devfs_mount.driver.create_file(devfs_root!, "tty", InodeModeFlags.TYPE_CHR);
		devfs_mount.driver.create_file(devfs_root!, "kbd", InodeModeFlags.TYPE_CHR);
		devfs_mount.driver.create_file(devfs_root!, "null", InodeModeFlags.TYPE_CHR);

		kernel.vfs.mount(this.tty, "/dev/tty");
		kernel.vfs.mount(new Kbd(this), "/dev/kbd");
		kernel.vfs.mount(new Null(this), "/dev/null");
	}

	step() {
		let event, p1, p2 = os.pullEventRaw();
		if (typeof event !== "string") { return; }
		switch (event) {
			case "timer":
				if (p1 === this.timer_id) {
					this.timer_id = os.startTimer(0.05);
				}
				break;
			case "char":
				if (typeof p1 === "string") {
					this.tty.push_input(p1);
				}
				break;
			case "key":
				this.kbd_queue.push({ event: "key_down", key: p1 });
				if (typeof p1 === "number") {
					let ch = KEY_TO_CHAR.get(p1);
					if (ch) { this.tty.push_input(ch); }
				}
				break;
			case "key_up":
				this.kbd_queue.push({ event: "key_up", key: p1 });
				break;
			case "terminate":
				let target_pid, target_proc;
				for (const [pid, proc] of this.kernel?.procman.processes!.entries()!) {
					if (pid !== 0 && !proc.dead) {
						if (target_pid === undefined || pid > target_pid!) {
							target_pid = pid;
							target_proc = proc;
						}
					}
				}
				if (target_proc) {
					target_proc.dead = true;
					target_proc.exit_code = -1;
				} else {
					os.shutdown();
				}
				break;
		}
	}
}
