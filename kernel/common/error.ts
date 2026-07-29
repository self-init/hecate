/** @noSelfInFile */

declare type ErrorCode =
	| "ENOENT"
	| "EACCES"
	| "EBADF"
	| "EEXIST"
	| "EISDIR"
	| "ENOEXEC"
	| "ENOTEMPTY"
	| "ENOTDIR";

export class KError extends Error {
	code: ErrorCode;
	cause?: KError;

	constructor(code: ErrorCode, message: string) {
		super();
		this.code = code;
	}
}

export type Result<T> = [ok: true, value: T] | [ok: false, value: KError];

export function ok<T>(v: T): Result<T> {
	return [true, v];
}

export function err<T>(code: ErrorCode, message: string): Result<T> {
	return [false, new KError(code, message)];
}

export function isOk<T>(r: Result<T>) {
	return r[0];
}

export function isErr<T>(r: Result<T>) {
	return !r[1];
}

export function unwrap<T>(r: Result<T>): T {
	if (!r[0]) { throw r[1]; }
	return r[1];
}



// export class Error {
// 	code: ErrorCode;
// 	message: string;

// 	constructor(code: ErrorCode, message: string) {
// 		this.code = code;
// 		this.message = message;
// 	}

// 	toString() {
// 		return this.code + ": " + this.message;
// 	}
// }

// export function err(code: ErrorCode, message: string): Error {
// 	return new Error(code, message);
// }

// function _throw(code: ErrorCode, message: string) {
// 	throw new Error(code, message);
// }

// export { _throw as throw };
