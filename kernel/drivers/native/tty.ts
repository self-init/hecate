import { BaseTty } from "../common/tty/init";

export class NativeTty extends BaseTty {
	write_raw(char: char): void {
		io.write(char);
		io.flush();
	}

	echo_erase(n: integer): void {
		io.write(string.rep("\x08 \x08", n));
		io.flush();
	}

	set_cursor_pos(x: integer, y: integer): void {
		io.write(string.format("\x27[%d;%dH", y, x))
		io.flush();
	}

	get_cursor_pos(): [integer, integer] {
		io.write("\x27[6n");
		io.flush();

		let res = io.read("*l") || "";

		let [row, col] = string.match(res, "\x27%[(%d+);(%d+)R");
		let row_num = tonumber(row);
		let col_num = tonumber(col);

		if (row_num !== undefined && col_num !== undefined) {
			return [row_num, col_num];
		} else {
			throw "Failed to parse cursor pos";
		}
	}

	get_term_size(): [integer, integer] {
		io.write("\x27[s\x27[9999;9999H\x27[6n\x27[u");
		io.flush();
		let res = io.read("*l") || "";

		let [rows, cols] = string.match(res, "(%d+);(%d+)R");
		let row_num = tonumber(rows);
		let col_num = tonumber(cols);
		if (row_num !== undefined && col_num !== undefined) {
			return [row_num, col_num];
		} else {
			throw "Failed to parse terminal size";
		}
	}

	clear_screen(): void {
		io.write("\x27[2J\x27[H");
		io.flush();
	}

	clear_to_eol(): void {
		io.write("\x27[K");
		io.flush();
	}

	clear_line(): void {
		io.write("\x27[2K\x27[1G");
		io.flush();
	}

	set_text_color(ansi: integer): void {
		io.write(string.format("\x27[%dm", ansi));
		io.flush();
	}

	set_bg_color(ansi: integer): void {
		io.write(string.format("\x27[%dm", ansi));
		io.flush();
	}

	reset_colors(): void {
		io.write("\x27[0m");
		io.flush();
	}

	set_cursor_visible(visible: boolean): void {
		io.write(visible ? "\x27[?25h" : "\x27[?25l");
		io.flush();
	}
}
