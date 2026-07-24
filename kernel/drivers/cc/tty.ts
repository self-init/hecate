import * as expect from "cc/expect";
import { BaseTty } from "../common/tty/init";

let ANSI_FG = new Map<integer, integer>([
	[30, colors.black],
	[31, colors.red],
	[32, colors.green],
	[33, colors.yellow],
	[34, colors.blue],
	[35, colors.purple],
	[36, colors.cyan],
	[37, colors.white],
]);

let ANSI_BG = new Map<integer, integer>([
	[40, colors.black],
	[41, colors.red],
	[42, colors.green],
	[43, colors.yellow],
	[44, colors.blue],
	[45, colors.purple],
	[46, colors.cyan],
	[47, colors.white],
]);

export class CCTty extends BaseTty {
	write_raw(char: char) {
		io.write(char);
	}

	echo_erase(n: integer) {
		let [x, y] = term.getCursorPos();
		term.setCursorPos(x - n, y);
		term.write(string.rep(" ", n));
		term.setCursorPos(x - n, y);
	}

	set_cursor_pos(x: integer, y: integer) {
		term.setCursorPos(x, y);
	}

	get_cursor_pos() {
		return term.getCursorPos();
	}

	get_term_size(): [integer, integer] {
		return term.getSize();
	}

	clear_screen(): void {
		term.clear();
		term.setCursorPos(1, 1);
	}

	clear_to_eol() {
		let [x, y] = term.getCursorPos();
		let [w, _] = term.getSize();
		term.write(string.rep(" ", w - x + 1));
		term.setCursorPos(x, y);
	}

	clear_line() {
		term.clearLine();
		let [_, y] = term.getCursorPos();
		term.setCursorPos(1, y);
	}

	set_text_color(ansi: integer) {
		let code = ANSI_FG.get(ansi);
		if (code !== undefined) {
			term.setTextColor(code);
		}
	}

	set_bg_color(ansi: integer) {
		let code = ANSI_BG.get(ansi);
		if (code !== undefined) {
			term.setBackgroundColor(code);
		}
	}

	reset_colors(): void {
		term.setTextColor(colors.white);
		term.setBackgroundColor(colors.black);
	}

	set_cursor_visible(visible: boolean): void {
		term.setCursorBlink(visible);
	}
}
