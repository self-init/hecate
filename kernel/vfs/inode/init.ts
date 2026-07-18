/** @noSelfInFile */
import { band, bnot, bor, btest } from "../../common/bitwise";

export type Inode = {
	id: integer;
	links: integer;
	size: integer;
	refs: integer;
	unlinked: boolean;
	owner: integer;
	group: integer;
	mode: integer;
}

export function create_inode(id: integer, file_type: InodeModeFlags, owner: integer, group: integer): Inode {
	let default_mode: integer = bor(
		InodeModeFlags.MASK_READ, InodeModeFlags.MASK_WRITE
	);

	if (file_type === InodeModeFlags.TYPE_DIR) {
		default_mode = InodeModeFlags.MASK_PERMS
	}

	return {
		id: id,
		links: 1,
		size: 0,
		refs: 0,
		unlinked: false,
		owner: owner,
		group: group,
		mode: bor(file_type, default_mode)
	}
}

export function get_inode_perms(inode: Inode, rew_mask: integer, uid: integer, gids: integer[]): boolean {
	let perms: integer = inode.mode;
	if (uid !== inode.owner) {
		perms = band(perms, bnot(InodeModeFlags.MASK_OWNER))
	}

	let is_in_group: boolean = false;
	for (const gid of gids) {
		if (gid === inode.group) {
			is_in_group = true;
			break;
		}
	}

	if (!is_in_group) {
		perms = band(perms, bnot(InodeModeFlags.MASK_GROUP))
	}

	return btest(perms, rew_mask);
}

export function get_inode_file_type(inode: Inode, flag: integer) {
	return btest(inode.mode, flag);
}
