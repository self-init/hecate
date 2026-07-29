import { Driver } from "../drivers/driver";
import type { Inode } from "./inode/init";

export type MountParentInfo = { mount: Mount, mountpoint: Inode }

export class Mount {
	driver: Driver;
	parent?: { mount: Mount, mountpoint: Inode };
	mountpoint_inode?: Inode;
	root_inode: Inode;
	children: Mount[];

	constructor(driver: Driver, root_inode: Inode, parent?: MountParentInfo) {
		this.driver = driver;
		this.parent = parent;
		this.root_inode = root_inode;
		this.children = [];
	}
}
