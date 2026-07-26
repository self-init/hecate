import { Kernel } from "../../kernel";
import { NativeArch } from "./arch";

function main() {
	let kernel = new Kernel(new NativeArch());
	// Array-destructure to capture xpcall's (ok, err) multi-return. Writing
	// `let ok, err = ...` declares two separate vars (ok stays undefined) and
	// makes tstl pack the returns into a table, so the panic would always fire
	// and print the raw table instead of the message.
	let [ok, err] = xpcall(kernel.start, debug.traceback, kernel);
	os.execute("stty sane 2>/dev/null");
	if (!ok) {
		io.write("\nkernel panic: " + tostring(err) + "\n");
	}
}

main();
