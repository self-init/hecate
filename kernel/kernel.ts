import Process from "processes.process";
import { Arch } from "./arch/arch";
import { RamFS } from "./drivers/agnostic/ramfs";
import { SerialFS } from "./drivers/agnostic/serialfs";
import { ProcessManager } from "./processes/manager";
import { Vfs } from "./vfs/vfs";

export class Kernel {
	arch: Arch;
	vfs: Vfs = new Vfs();
	procman: ProcessManager = new ProcessManager();

	constructor(arch: Arch) {
		this.arch = arch;
	}

	start() {
		let rootfs = new SerialFS(this.arch, "rootfs.dat");
		this.vfs.mount(rootfs, "/");

		if (rootfs.get_inode("/dev") === undefined) {
			rootfs.create_file(this.vfs.root_mount?.root_inode!, "dev", InodeModeFlags.TYPE_DIR)
		}

		let devfs = new RamFS(this.arch);
		this.vfs.mount(devfs, "/dev");
		this.arch.init(this);

		let init_process = new Process(this, "/bin/init.lua");
		this.procman.add_process(init_process);

		while (true) {
			this.arch.step();
			this.procman.step();
			let init = this.procman.get_process(1);
			if (init === null || init.dead) {
				throw "kernel panic: init (PID 1) died with exit code " + tostring(init && init.exit_code);
			}
		}
	}
}
