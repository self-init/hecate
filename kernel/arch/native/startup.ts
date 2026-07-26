import { Kernel } from "../../kernel";
import { NativeArch } from "./arch";

function main() {
	let kernel = new Kernel(new NativeArch());
	let ok, err = xpcall(kernel.start, debug.traceback, kernel);
	os.execute("stty sane 2>/dev/null");
	if (!ok) {
		io.write("\nkernel panic: " + tostring(err) + "\n");
	}
}

main();
