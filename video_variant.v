module vfile_thumbnail

import os
import stbi

pub fn video_placeholder_variant_for_size(size string) !Variant {
	return match size {
		'web' { video_placeholder_variant(512, 288)! }
		'thumb' { video_placeholder_variant(teedy_thumb_variant_max, teedy_thumb_variant_max)! }
		else { error('video placeholder size must be web or thumb') }
	}
}

pub fn video_placeholder_variant_for_size_with_dimensions(size string, source_width int, source_height int) !Variant {
	if source_width <= 0 || source_height <= 0 {
		return video_placeholder_variant_for_size(size)
	}
	width, height := match size {
		'web' {
			fit_image_dimensions(source_width, source_height, 512, 512)
		}
		'thumb' {
			fit_image_dimensions(source_width, source_height, teedy_thumb_variant_max,
				teedy_thumb_variant_max)
		}
		else {
			return error('video placeholder size must be web or thumb')
		}
	}

	return video_placeholder_variant(width, height)
}

fn video_placeholder_variant(width int, height int) !Variant {
	mut pixels := new_rgba_canvas(width, height, Color{17, 24, 39, 255})
	draw_video_frame(mut pixels, width, height)
	path := temp_variant_path('png')
	defer {
		os.rm(path) or {}
	}
	stbi.stbi_write_png(path, width, height, 4, pixels.data, width * 4)!
	return Variant{
		mime_type: 'image/png'
		bytes:     os.read_bytes(path)!
		width:     width
		height:    height
	}
}

fn draw_video_frame(mut pixels []u8, width int, height int) {
	bar_h := max_int(4, height / 18)
	fill_rect(mut pixels, width, height, 0, 0, width, bar_h, Color{31, 41, 55, 255})
	fill_rect(mut pixels, width, height, 0, height - bar_h, width, bar_h, Color{31, 41, 55, 255})
	button_r := max_int(24, min_int(width, height) / 5)
	cx := width / 2
	cy := height / 2
	draw_disc(mut pixels, width, height, cx, cy, button_r, Color{243, 244, 246, 255})
	draw_play_triangle(mut pixels, width, height, cx - button_r / 4, cy, button_r, Color{17, 24, 39, 255})
}

fn draw_disc(mut pixels []u8, width int, height int, cx int, cy int, radius int, color Color) {
	r2 := radius * radius
	for y in max_int(0, cy - radius) .. min_int(height, cy + radius + 1) {
		for x in max_int(0, cx - radius) .. min_int(width, cx + radius + 1) {
			dx := x - cx
			dy := y - cy
			if dx * dx + dy * dy <= r2 {
				idx := (y * width + x) * 4
				pixels[idx] = color.r
				pixels[idx + 1] = color.g
				pixels[idx + 2] = color.b
				pixels[idx + 3] = color.a
			}
		}
	}
}

fn draw_play_triangle(mut pixels []u8, width int, height int, x0 int, cy int, size int, color Color) {
	half_h := size / 2
	for y in max_int(0, cy - half_h) .. min_int(height, cy + half_h + 1) {
		row_from_center := abs_int(y - cy)
		row_w := max_int(1, half_h - row_from_center)
		x1 := x0 + size / 2 + row_w
		for x in max_int(0, x0) .. min_int(width, x1) {
			idx := (y * width + x) * 4
			pixels[idx] = color.r
			pixels[idx + 1] = color.g
			pixels[idx + 2] = color.b
			pixels[idx + 3] = color.a
		}
	}
}

fn min_int(a int, b int) int {
	return if a < b { a } else { b }
}

fn abs_int(value int) int {
	return if value < 0 { -value } else { value }
}
