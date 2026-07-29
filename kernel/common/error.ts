/** @noSelfInFile */

declare type ErrorCode =
	| "ENOENT"
	| "EACCES"
	| "EBADF"
	| "EEXIST"
	| "EISDIR"
	| "ENOEXEC"
	| "ENOTEMPTY"
	| "ENOTDIR"
	| "EPERM"
	| "EINVAL"
	| "EIO"
	| "EAGAIN"
	| "ENOSPC"
	| "EMFILE";

export class KError extends Error {
	code: ErrorCode;
	cause?: KError;

	constructor(code: ErrorCode, message: string) {
		super();
		this.code = code;
	}


}

export type Result<T> = { ok: true, value: T } | { ok: false, error: KError };

export function ok<T>(v: T): Result<T> {
	return { ok: true, value: v };
}

export function err<T>(code: ErrorCode, message: string): Result<T> {
	return { ok: false, error: new KError(code, message) };
}

export function isOk<T>(r: Result<T>) {
	return r.ok;
}

export function isErr<T>(r: Result<T>) {
	return !r.ok;
}

export function unwrap<T>(r: Result<T>): T {
	if (!r.ok) { throw r.error; }
	return r.value;
}

export function success(): Result<void> {
	return { ok: true, value: undefined };
}

export function fromCatch(e: unknown): KError {
	if (e instanceof KError) return e;
	return new KError("EIO", tostring(e));
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
