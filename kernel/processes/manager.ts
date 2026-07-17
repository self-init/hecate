import * as Process from "processes.process";

let NUM_QUEUES: integer = 3;
let QUANTA: integer[] = [2, 4, 8]; // slices per queue before demotion
let BOOST_INTERVAL = 50; // steps between starvation-prevention boosts
let INSTRUCTION_QUOTA = 500; // vm instructions per slice in preemptive mode

type MetaInfo = { queue_level: integer, ticks_used: integer }

export class ProcessManager {
	process_id: integer = 1;
	processes: Process[] = [];
	active_process: Process | null = null;
	queues: Process[][] = [];
	meta: MetaInfo[] = [];
	tick_count: integer = 0;
	preemptive: boolean = this.detect_preemption();

	constructor(arch: unknown) {
		for (let i = 0; i < NUM_QUEUES; i++) {
			this.queues.push([]);
		}
	}

	private detect_preemption() {
		let co = coroutine.create(function () { while (true) { } });
		debug.sethook(co, coroutine.yield, "", 50);
		let ok = coroutine.resume(co);
		// @ts-expect-error the library type for coroutines appears to be wrong
		debug.sethook(co, null);
		return ok && coroutine.status(co) == "suspended";
	}

	add_process(process: Process) {
		process.pid = this.process_id;
		this.process_id += 1;
		this.processes[process.pid] = process;

		this.meta[process.pid] = {
			queue_level: 0,
			ticks_used: 0
		};

		this.queues[0].push(process);
	}

	get_process(pid: integer): Process | null {
		return this.processes[pid] ?? null;
	}

	remove_process(pid: integer) {
		if (this.processes[pid]) {
			this.processes[pid].dead = true
		}

		delete this.processes[pid];
		delete this.meta[pid];
	}

	private next_process(): LuaMultiReturn<[Process, integer] | [null, null]> {
		for (let level = 0; level < NUM_QUEUES; level++) {
			let queue = this.queues[level]
			while (queue.length > 0) {
				let process = queue.shift();
				if (process !== undefined && !process.dead) {
					return $multi(process, level);
				}
			}
		}
		return $multi(null, null);
	}

	private boost_all() {
		for (let level = 1; level < NUM_QUEUES; level++) {
			for (const process of this.queues[level]) {
				if (!process.dead) {
					let meta = this.meta[process.pid];
					if (meta !== null) {
						meta.queue_level = 0;
						meta.ticks_used = 0;
					}
					this.queues[0].push(process);
				}
			}
			this.queues[level] = [];
		}
	}

	step(): boolean {
		this.tick_count += 1;

		if (this.tick_count % BOOST_INTERVAL === 0) {
			this.boost_all();
		}

		let [process, level] = this.next_process();
		if (process === null || level === null) { return false; }

		this.active_process = process;
		let meta = this.meta[process.pid];

		if (this.preemptive) {
			debug.sethook(process.coroutine, coroutine.yield, "", INSTRUCTION_QUOTA);
		}

		let [ok, err] = coroutine.resume(process.coroutine);

		if (this.preemptive) {
			// @ts-expect-error the library type for coroutines appears to be wrong
			debug.sethook(process.coroutine, null);
		}

		this.active_process = null;

		if (!ok) {
			let stderr = process.fds[2];
			if (stderr !== null) {
				stderr.write(tostring(err) + "\n");
			}
			process.dead = true;
			process.exit_code = -1;
			delete this.meta[process.pid];
			return true;
		}

		if (coroutine.status(process.coroutine) === "dead") {
			process.dead = true;
			process.exit_code = process.exit_code || 0;
			delete this.meta[process.pid];
			return true;
		}

		if (meta === null) { return true; }
		meta.ticks_used += 1;

		if (meta.ticks_used >= QUANTA[level]) {
			meta.ticks_used = 0;

			let new_level = math.min(level + 1, NUM_QUEUES - 1);
			meta.queue_level = new_level;
			this.queues[new_level].push(process);
		} else {
			this.queues[level].push(process);
		}

		return true;
	}
}

export function create(arch: unknown): ProcessManager {
	return new ProcessManager(arch);
}
