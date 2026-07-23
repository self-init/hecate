import { BiMap } from "../../common/bimap";
import { Inode } from "../../vfs/inode/init";
import { BaseFS } from "../common/basefs";

function serialize(value: unknown, indent: string = ""): string {
	let t = type(value);

	switch(t) {
		case "string":
			return string.format("q", value);
		case "number":
		case "boolean":
			return tostring(value);
		case "table":
			let parts: string[] = [];
			let ni = indent + "  ";
			for (const [k, v] of pairs(value)) {
				let key = typeof(k) === "string" && string.match(k, "^[%a_][%w_]*$") ? k : ("[" + serialize(k) + "]");
				parts.push(ni + key + "=" + serialize(v, ni));
			}
			if (parts.length === 0) { return "{}" };
			return "{\n" + parts.join(",\n") + "\n" + indent + "}";
		default:
			return "nil"
	}
}

class SerialFS extends BaseFS {
	host_path: Path;
	data: Map<integer, string> = new Map();

	constructor(arch: unknown, host_path: Path) {
		super(arch);
		this.host_path = host_path;
	}

	private save() {
		let f = assert(io.open(this.host_path, "w"))[0];
		if (f === undefined) { return; }
		f.write(serialize({
			inode_id: this.inode_id,
			inodes: this.inodes,
			paths: this.inode_path_map.entries(),
			data: this.data
		}));
		f.close();
	}

	private static load(host_path: Path): LuaTable | null {
		let f = assert(io.open(host_path, "r"))[0];
		if (f === undefined) { return null; }
		let content = f.read("*a");
		f.close();
		let fn = load("return " + content)[0];
		if (fn === undefined) { return null; }
		return fn();
	}

	mount(resolved_path: Path): Inode {
		let state = SerialFS.load(this.host_path);
		if (state !== null) {
			this.inode_id = state.get("inode_id");
			this.inodes = state.get("inodes");
			this.data = state.get("data");
			let map = new BiMap<Path, integer>();
			for (const [path, id] of pairs(state.get("paths"))) {
				if (typeof(path) !== "string") { throw "Attempted to load malformed serial file"; }
				map.set(path, id);
			}
			this.inode_path_map = map;
			let returned_inode = this.inode_path_map.get(resolved_path);
			if (returned_inode === undefined) { throw "idek this is getting depricated"; }
			return this.inodes[returned_inode];
		} else {
			let inode = super.mount(resolved_path);
			this.save();
			return inode;
		}
	}

	create_file(parent_inode: Inode, name: string, type: InodeModeFlags): Inode {
		let inode = super.create_file(parent_inode, name, type);
		this.save();
		return inode;
	}

	destroy_file(inode: Inode): void {
		super.destroy_file(inode);
		if (!inode.unlinked) {
			this.data.delete(inode.id)
		}
		this.save();
	}

	free_inode(inode: Inode): void {
		super.free_inode(inode);
		this.data.delete(inode.id);
		this.save();
	}

	read_file(inode: globalThis.Inode, offset: integer, length: integer): string {
		let contents = this.data.get(inode.id) || "";
		return string.sub(contents, offset + 1, offset + length);
	}

	write_file(inode: globalThis.Inode, offset: integer, data: string): integer {
		let contents = this.data.get(inode.id) || "";
		let prefix = string.sub(contents, offset);
		if (prefix.length < offset) {
			prefix = prefix + string.rep("\0", offset - prefix.length);
		}
		let suffix = string.sub(contents, offset + data.length + 1);
		let new_contents = prefix + data + suffix;
		this.data.set(inode.id, new_contents);
		inode.size = new_contents.length;
		this.save();
		return data.length;
	}

	ioctl(inode: globalThis.Inode, request: integer, arg: any): unknown {
		return;
	}
}
