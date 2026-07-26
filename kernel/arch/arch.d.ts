import { Kernel } from "../kernel";

export interface Arch {
	init(kernel: Kernel): void;
	step(): void;
}
