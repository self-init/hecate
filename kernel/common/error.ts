/** @noSelfInFile */

export const ENOENT = "ENOENT";
export const EACCES = "EACCES";
export const EBADF = "EBADF";
export const EEXIST = "EEXIST";
export const EISDIR = "EISDIR";
export const ENOEXEC = "ENOEXEC";
export const ENOTEMPTY = "ENOTEMPTY";
export const ENOTDIR = "ENOTDIR";

export class Error {
	code: ErrorCode;
	message: string;

	constructor(code: ErrorCode, message: string) {
		this.code = code;
		this.message = message;
	}

	toString() {
		return this.code + ": " + this.message;
	}
}

export function err(code: ErrorCode, message: string): Error {
	return new Error(code, message);
}

function _throw(code: ErrorCode, message: string) {
	throw new Error(code, message);
}

export { _throw as throw };
