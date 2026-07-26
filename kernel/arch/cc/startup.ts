import { Kernel } from "../../kernel";
import { CCArch } from "./arch";

function main() {
	term.clear();
	term.setCursorPos(1, 1);
	let kernel = new Kernel(new CCArch());
	kernel.start();
}
