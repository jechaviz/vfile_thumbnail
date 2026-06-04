module vfile_thumbnail

import os
import stbi

struct Color {
	r u8
	g u8
	b u8
	a u8
}

fn new_rgba_canvas(width int, height int, color Color) []u8 {
	mut pixels := []u8{len: width * height * 4}
	fill_rect(mut pixels, width, height, 0, 0, width, height, color)
	return pixels
}

fn fill_rect(mut pixels []u8, width int, height int, x int, y int, w int, h int, color Color) {
	x0 := clamp_int(x, 0, width)
	y0 := clamp_int(y, 0, height)
	x1 := clamp_int(x + w, 0, width)
	y1 := clamp_int(y + h, 0, height)
	for py in y0 .. y1 {
		for px in x0 .. x1 {
			idx := (py * width + px) * 4
			pixels[idx] = color.r
			pixels[idx + 1] = color.g
			pixels[idx + 2] = color.b
			pixels[idx + 3] = color.a
		}
	}
}

fn jpeg_variant_from_pixels(width int, height int, pixels []u8, quality int) !Variant {
	path := temp_variant_path('jpg')
	defer {
		os.rm(path) or {}
	}
	stbi.stbi_write_jpg(path, width, height, 4, pixels.data, quality)!
	return Variant{
		mime_type: 'image/jpeg'
		bytes:     os.read_bytes(path)!
		width:     width
		height:    height
	}
}

fn clamp_int(value int, min_value int, max_value int) int {
	if value < min_value {
		return min_value
	}
	if value > max_value {
		return max_value
	}
	return value
}
