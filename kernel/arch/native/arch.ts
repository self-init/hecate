import { Null } from "../../drivers/agnostic/null";
import { Kbd } from "../../drivers/native/kbd";
import { NativeTty } from "../../drivers/native/tty";
import { Kernel } from "../../kernel";
import { Arch } from "../arch";

export class NativeArch implements Arch {
	tty: NativeTty = new NativeTty(this);

	init(kernel: Kernel): void {
		// min 0 time 1: io.read(1) returns after at most 100ms with no data
    os.execute("stty raw -echo min 0 time 1 2>/dev/null")

		let [devfs_mount, devfs_root] = kernel.vfs.namei("/dev");
		devfs_mount.driver.create_file(devfs_root!, "tty", InodeModeFlags.TYPE_CHR);
		devfs_mount.driver.create_file(devfs_root!, "kbd", InodeModeFlags.TYPE_CHR);
		devfs_mount.driver.create_file(devfs_root!, "null", InodeModeFlags.TYPE_CHR);

		kernel.vfs.mount(this.tty, "/dev/tty");
		kernel.vfs.mount(new Kbd(this), "/dev/kbd");
		kernel.vfs.mount(new Null(this), "/dev/null");
	}

	step(): void {
		let ch = io.read(1);
		if (ch === undefined || ch.length === 0) { return; }

		if (ch === "\x03") {
			os.execute("stty sane 2>/dev/null")
      os.exit(1)
		}

		if (string.byte(ch) === 127) { ch = "\x08"; }
		this.tty.push_input(ch);
	}
}
