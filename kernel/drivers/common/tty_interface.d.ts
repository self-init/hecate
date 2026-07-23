export interface Tty {
	write_raw(ch: char): void;
	echo_erase(n: integer): void;
	set_cursor_pos(x: integer, y: integer): void;
	get_cursor_pos(): [integer, integer];
	get_term_size(): [integer, integer];
	clear_screen(): void;
	clear_to_eol(): void;
	clear_line(): void;
	set_text_color(ansi: integer): void;
	set_bg_color(ansi: integer): void;
	reset_colors(): void;
	set_cursor_visible(visible: boolean): void;
}
