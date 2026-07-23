export abstract class Driver {
	arch: unknown;

	constructor(arch: unknown) {
		this.arch = arch;
	};

	abstract mount(path: Path): Inode;
	abstract unmount(path: Path): void;
	abstract get_inode(path: Path): Inode | undefined;
	abstract lookup(dir_inode: Inode, name: string): Inode | undefined;
	abstract read_dir(inode: Inode): string[];
	abstract create_file(parent_inode: Inode, name: string, type: InodeModeFlags): Inode;
	abstract destroy_file(inode: Inode): void;
	abstract read_file(inode: Inode, offset: integer, length: integer): string;
	abstract write_file(inode: Inode, offset: integer, data: string): integer;
	abstract ioctl(inode: Inode, request: integer, arg: any): unknown;
}
