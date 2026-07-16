/** @noSelfInFile */

// returns an iterator that steps through the individual components of a string
export function iterator(path_string: Path): LuaIterable<LuaMultiReturn<string[]>, undefined> {
	return string.gmatch(path_string, "([^/]+)")
}

// splits a path by its components
export function split(path_string: Path): Path[] {
	let parts: Path[] = [];
	for (const [part] of iterator(path_string)) {
		parts.push(part);
	}
	return parts;
}

// joins two or mor paths together into a single path
export function join(...paths: Path[]): Path {
	let joined_path: Path = "";
	for (const path of paths) {
		// skip the first path
		if (joined_path === "") {
			joined_path = path;
			continue;
		}
		// Check each if the current path begins with "/"
		// or the next path ends with "/"
		let joined_suffix: boolean = string.sub(joined_path, -1) === "/";
		let path_prefix = string.sub(path, 1, 1) === "/";
		if (joined_suffix && path_prefix) {
			// remove one "/" if both are found
			joined_path += string.sub(path, 2);
		} else if (joined_suffix || path_prefix) {
			// join if only one has "/"
			joined_path += path;
		} else {
			// add "/" if neither path has one
			joined_path += "/" + path;
		}
	}
	return joined_path;
}

// Resolves the full path of a string from a rel path and the working directory
export function resolve(rel_path: Path, wd_path: Path): Path {
	if (string.sub(rel_path, 1, 1) !== "/") {
		rel_path = join(wd_path, rel_path);
	}

	let path_parts: string[] = [];

	for (const part in iterator(rel_path)) {
		if (part === ".") {
			continue;
		} else if (part === "..") {
			path_parts.pop();
		} else {
			path_parts.push(part);
		}
	}

	let resolved_path = path_parts.join("") + "/";
	return "/" + resolved_path;
}
