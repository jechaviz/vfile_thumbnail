module vfile_thumbnail

const text_web_width = 960
const text_web_height = 1280
const text_thumb_width = 192
const text_thumb_height = 256

pub struct TextVariantInput {
pub:
	name string
	text string
}

pub fn text_variant_for_size(input TextVariantInput, size string) !Variant {
	return match size {
		'web' { text_variant(input, text_web_width, text_web_height, 4, 88)! }
		'thumb' { text_variant(input, text_thumb_width, text_thumb_height, 2, 82)! }
		else { error('text variant size must be web or thumb') }
	}
}

fn text_variant(input TextVariantInput, width int, height int, scale int, quality int) !Variant {
	mut pixels := new_rgba_canvas(width, height, Color{242, 244, 247, 255})
	margin := 6 * scale
	page_x := 3 * scale
	page_y := 3 * scale
	page_w := width - page_x * 2
	page_h := height - page_y * 2
	fill_rect(mut pixels, width, height, page_x, page_y, page_w, page_h, Color{255, 255, 255, 255})
	draw_rect(mut pixels, width, height, page_x, page_y, page_w, page_h, Color{203, 213, 225, 255})

	title := if input.name.trim_space() == '' { 'Text file' } else { input.name.trim_space() }
	draw_text_line(mut pixels, width, height, page_x + margin, page_y + margin, title, scale, Color{15, 23, 42, 255})
	y_start := page_y + margin + 11 * scale
	char_w := 6 * scale
	line_h := 9 * scale
	max_chars := max_int(8, (page_w - margin * 2) / char_w)
	max_lines := max_int(1, (page_h - (y_start - page_y) - margin) / line_h)
	lines := wrapped_ascii_lines(input.text, max_chars, max_lines)
	mut y := y_start
	for line in lines {
		draw_text_line(mut pixels, width, height, page_x + margin, y, line, scale, Color{51, 65, 85, 255})
		y += line_h
	}
	return jpeg_variant_from_pixels(width, height, pixels, quality)!
}

fn wrapped_ascii_lines(text string, max_chars int, max_lines int) []string {
	clean := ascii_preview_text(text)
	mut out := []string{}
	for raw in clean.split('\n') {
		mut rest := raw
		for rest.len > max_chars {
			out << rest[..max_chars]
			rest = rest[max_chars..]
			if out.len >= max_lines {
				return out
			}
		}
		out << rest
		if out.len >= max_lines {
			return out
		}
	}
	if out.len == 0 {
		out << ' '
	}
	return out
}

fn ascii_preview_text(text string) string {
	mut bytes := []u8{cap: text.len}
	for b in text.bytes() {
		if b == `\r` {
			continue
		}
		if b == `\n` || b == `\t` {
			bytes << if b == `\t` { ` ` } else { b }
			continue
		}
		bytes << if b >= 32 && b <= 126 { b } else { `?` }
	}
	return bytes.bytestr()
}

fn draw_text_line(mut pixels []u8, width int, height int, x int, y int, text string, scale int, color Color) {
	mut cursor := x
	for ch in text.bytes() {
		draw_glyph(mut pixels, width, height, cursor, y, ch, scale, color)
		cursor += 6 * scale
		if cursor >= width - scale {
			return
		}
	}
}

fn draw_glyph(mut pixels []u8, width int, height int, x int, y int, ch u8, scale int, color Color) {
	rows := glyph_rows(ch)
	for row_idx, row in rows {
		for col_idx, bit in row.bytes() {
			if bit == `1` {
				fill_rect(mut pixels, width, height, x + col_idx * scale, y + row_idx * scale,
					scale, scale, color)
			}
		}
	}
}

fn draw_rect(mut pixels []u8, width int, height int, x int, y int, w int, h int, color Color) {
	fill_rect(mut pixels, width, height, x, y, w, 1, color)
	fill_rect(mut pixels, width, height, x, y + h - 1, w, 1, color)
	fill_rect(mut pixels, width, height, x, y, 1, h, color)
	fill_rect(mut pixels, width, height, x + w - 1, y, 1, h, color)
}

fn max_int(a int, b int) int {
	return if a > b { a } else { b }
}
