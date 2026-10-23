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

// removes trailing slashes, leaving a lone "/" intact
function strip_trailing(path_string: Path): Path {
	let [stripped] = string.gsub(path_string, "/+$", "");
	if (stripped === "" && string.sub(path_string, 1, 1) === "/") {
		return "/";
	}
	return stripped;
}

// returns the parent directory of a path, "." for a bare relative name
export function dirname(path_string: Path): Path {
	path_string = strip_trailing(path_string);
	let [parent] = string.match(path_string, "^(.*)/[^/]*$");
	if (parent === undefined) {
		return ".";
	} else if (parent === "") {
		return "/";
	}
	return parent;
}

// returns the last component of a path
export function basename(path_string: Path): Path {
	path_string = strip_trailing(path_string);
	if (path_string === "/") {
		return "/";
	}
	let [name] = string.match(path_string, "[^/]+$");
	return name ?? path_string;
}

// Resolves the full path of a string from a rel path and the working directory
export function resolve(rel_path: Path, wd_path: Path): Path {
	if (string.sub(rel_path, 1, 1) !== "/") {
		rel_path = join(wd_path, rel_path);
	}

	let path_parts: string[] = [];

	for (const [part] of iterator(rel_path)) {
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
