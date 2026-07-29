import { BaseTty } from "../common/tty/init";

class Pty extends BaseTty {
	output_buf: string[] = [];

	private write(data: string) {
		this.output_buf.push(data);
	}

	read_output(length: integer) {
		if (this.output_buf.length === 0) { return undefined; }
		let chunk = this.output_buf.shift();
		if (chunk !== undefined && length > 0 && chunk.length >= length) {
			this.output_buf.push(string.sub(chunk, length + 1));
			chunk = string.sub(chunk, 1, length);
			return chunk;
		}
		return undefined;
	}

	write_raw(char: char): void { }
	echo_erase(n: integer): void { }
	set_cursor_pos(x: integer, y: integer): void { }
	get_cursor_pos(): [integer, integer] { return [0, 0]	}
	get_term_size(): [integer, integer] { return [0, 0] }
	clear_screen(): void { }
	clear_to_eol(): void { }
	clear_line(): void { }
	set_text_color(ansi: integer): void { }
	set_bg_color(ansi: integer): void { }
	reset_colors(): void { }
	set_cursor_visible(visible: boolean): void { }
}
