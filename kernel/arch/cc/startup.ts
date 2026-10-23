import { Kernel } from "../../kernel";
import { CCArch } from "./arch";

function main() {
	term.clear();
	term.setCursorPos(1, 1);
	let kernel = new Kernel(new CCArch());
	// Array-destructure to capture xpcall's (ok, err) multi-return (see the
	// native startup for why `let ok, err = ...` doesn't work under tstl).
	let [ok, err] = xpcall(() => kernel.start(), debug.traceback);
	if (!ok) {
		printError("kernel panic: " + tostring(err));
	}
	print("Press any key to shut down.");
	// pullEventRaw (not pullEvent) so Ctrl+T's "terminate" can't abort the wait;
	// any non-"key" event, terminate included, is ignored.
	while (true) {
		let [event] = os.pullEventRaw();
		if (event === "key") { break; }
	}
	os.shutdown();
}

main();
