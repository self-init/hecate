/** @noSelfInFile */

type UnaryOp = (a: number) => number;
type BinaryOp = (a: number, b: number) => number;

/** @noSelf */
interface BitwiseFunctions {
	band: BinaryOp;
	bor: BinaryOp;
	bxor: BinaryOp;
	bnot: UnaryOp;
	lshift: BinaryOp;
	rshift: BinaryOp;
	arshift: BinaryOp;
	btest: (a: number, b: number) => boolean;
	extract: (a: number, start_bit: number, width?: number) => number;
	replace: (a: number, value: number, start_bit: number, width?: number) => number;
	lrotate: BinaryOp;
	rrotate: BinaryOp;
}

// Lua-version detection stays a runtime check, not a tstl compile target,
// because a single native build ships to whatever Lua interpreter the end
// user has installed (see Makefile's native_kernel target) - unknown at
// compile time. Revisit if/when the build starts emitting per-version bundles.
function make(): BitwiseFunctions {
	const version = _VERSION as string;

	if (version === "Lua 5.3" || version === "Lua 5.4" || version === "Lua 5.5") {
		const band = load("return function(a,b) return a & b  end")[0]!() as BinaryOp;
		const bor = load("return function(a,b) return a | b  end")[0]!() as BinaryOp;
		const bxor = load("return function(a,b) return a ~ b  end")[0]!() as BinaryOp;
		const bnot = load("return function(a)   return ~a      end")[0]!() as UnaryOp;
		const lshift = load("return function(a,b) return a << b  end")[0]!() as BinaryOp;
		const rshift = load("return function(a,b) return a >> b  end")[0]!() as BinaryOp;
		const arshift = load("return function(a,b) return a >> b  end")[0]!() as BinaryOp;

		const btest = (a: number, b: number) => band(a, b) !== 0;

		const extract = (a: number, start_bit: number, width = 1) => {
			const mask = lshift(1, width) - 1;
			return band(rshift(a, start_bit), mask);
		};

		const replace = (a: number, value: number, start_bit: number, width = 1) => {
			const mask = lshift(lshift(1, width) - 1, start_bit);
			const shifted_value = lshift(value, start_bit);
			return bor(band(a, bnot(mask)), band(shifted_value, mask));
		};

		const lrotate = (a: number, b: number) => {
			const shift = b % 32;
			return bor(lshift(a, shift), rshift(a, 32 - shift));
		};

		const rrotate = (a: number, b: number) => {
			const shift = b % 32;
			return bor(rshift(a, shift), lshift(a, 32 - shift));
		};

		return { band, bor, bxor, bnot, lshift, rshift, arshift, btest, extract, replace, lrotate, rrotate };
	}

	// Lua nil and undefined are the same thing to tstl - a plain truthiness
	// check is the correct "is this present" test, not `!== null`.
	const bit32lib = _G.bit32;

	if (bit32lib !== null) {
		return {
			band: bit32lib.band,
			bor: bit32lib.bor,
			bxor: bit32lib.bxor,
			bnot: bit32lib.bnot,
			lshift: bit32lib.lshift,
			rshift: bit32lib.rshift,
			arshift: bit32lib.arshift,
			btest: bit32lib.btest,
			extract: bit32lib.extract,
			replace: bit32lib.replace,
			lrotate: bit32lib.lrotate,
			rrotate: bit32lib.rrotate,
		};
	}

	error("common.bitwise requires Lua 5.2 or newer");
}

const functions = make();

export const band = functions.band;
export const bor = functions.bor;
export const bxor = functions.bxor;
export const bnot = functions.bnot;
export const lshift = functions.lshift;
export const rshift = functions.rshift;
export const arshift = functions.arshift;
export const btest = functions.btest;
export const extract = functions.extract;
export const replace = functions.replace;
export const lrotate = functions.lrotate;
export const rrotate = functions.rrotate;

// Only needed at the userspace-exposure boundary (process.lua hands this
// module's exports table into a process's sandboxed env). TS `readonly` is
// erased by tstl, so this is the only real runtime write-protection available.
export function freeze<T extends object>(original: T): Readonly<T> {
	const proxy = {} as T;
	setmetatable(proxy, {
		__index: original,
		__newindex: () => {
			error("Attempt to modify a read-only table.", 2);
		},
		__metatable: "Metatable is protected",
	});
	return proxy;
}
