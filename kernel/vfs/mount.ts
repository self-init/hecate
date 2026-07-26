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

export function create(driver: Driver, parent: Mount | null, mountpoint_inode : Inode | null, root_inode: Inode): Mount {
	let parent_info: MountParentInfo | undefined = undefined;

	if (parent !== null && mountpoint_inode !== null) {
		parent_info = { mount: parent, mountpoint: mountpoint_inode };
	}

	return new Mount(driver, root_inode, parent_info);
}
