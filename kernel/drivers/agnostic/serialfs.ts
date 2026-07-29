import { BiMap } from "../../common/bimap";
import { Inode } from "../../vfs/inode/init";
import { BaseFS } from "../common/basefs";
import type { Arch } from "../../arch/arch";

function serialize(value: unknown, indent: string = ""): string {
	let t = type(value);

	switch(t) {
		case "string":
			return string.format("%q", value);
		case "number":
		case "boolean":
			return tostring(value);
		case "table":
			let parts: string[] = [];
			let ni = indent + "  ";
			for (const [k, v] of pairs(value)) {
				// Bare identifier keys can be written unquoted; everything else
				// (paths with "/", numeric keys) must be bracketed+quoted. Note
				// the match is destructured to a single value: used directly in
				// a boolean, tstl wraps the multi-return in a table that is
				// always truthy, which would emit paths unquoted.
				let key: string;
				if (typeof(k) === "string") {
					let [ident] = string.match(k, "^[%a_][%w_]*$");
					key = ident !== undefined ? k : "[" + serialize(k) + "]";
				} else {
					key = "[" + serialize(k) + "]";
				}
				parts.push(ni + key + "=" + serialize(v, ni));
			}
			if (parts.length === 0) { return "{}" };
			return "{\n" + parts.join(",\n") + "\n" + indent + "}";
		default:
			return "nil"
	}
}

export class SerialFS extends BaseFS {
	host_path: Path;
	data: Map<integer, string> = new Map();

	constructor(arch: Arch, host_path: Path) {
		super(arch);
		this.host_path = host_path;
	}

	private save() {
		let [f] = io.open(this.host_path, "w");
		if (f === undefined) { return; }

		// On-disk layout is a plain, tool-friendly format (see
		// build/mkserialfs.lua): inodes and data keyed by inode id, paths as
		// path -> id. Convert the in-memory tstl structures (a 1-based array,
		// a Map and a BiMap) into that plain form so the file round-trips and
		// stays compatible with the build-time packer.
		let inodes = new LuaTable<integer, Inode>();
		for (const [_, inode] of pairs(this.inodes as unknown as LuaTable<integer, Inode>)) {
			inodes.set(inode.id, inode);
		}
		let data = new LuaTable<integer, string>();
		for (const [id, content] of this.data) {
			data.set(id, content);
		}
		let paths = new LuaTable<Path, integer>();
		for (const [path, id] of this.inode_path_map.entries()) {
			paths.set(path, id);
		}

		f.write(serialize({
			inode_id: this.inode_id,
			inodes: inodes,
			paths: paths,
			data: data
		}));
		f.close();
	}

	private static load(host_path: Path): LuaTable | undefined {
		let [f] = io.open(host_path, "r");
		if (f === undefined) { return undefined; }
		let content = f.read("*a");
		f.close();
		let fn = load("return " + content)[0];
		if (fn === undefined) { return undefined; }
		return fn();
	}

	mount(resolved_path: Path): Inode {
		let state = SerialFS.load(this.host_path);
		if (state !== undefined) {
			this.inode_id = state.get("inode_id");

			// Rebuild the in-memory structures from the plain on-disk layout.
			// Assigning through the typed fields lets tstl apply its array
			// (1-based) and Map representations; a raw assignment of the disk
			// tables would leave inodes off-by-one and data as a non-Map.
			let inodes: Inode[] = [];
			for (const [id, inode] of pairs(state.get("inodes") as LuaTable<integer, Inode>)) {
				inodes[id] = inode;
			}
			this.inodes = inodes;

			let data = new Map<integer, string>();
			for (const [id, content] of pairs(state.get("data") as LuaTable<integer, string>)) {
				data.set(id, content);
			}
			this.data = data;

			let map = new BiMap<Path, integer>();
			for (const [path, id] of pairs(state.get("paths") as LuaTable<Path, integer>)) {
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
