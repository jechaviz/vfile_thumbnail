module vfile_thumbnail

import math
import os
import rand
import stbi

pub const teedy_web_variant_max = 1280
pub const teedy_thumb_variant_max = 256

pub struct VariantOptions {
pub:
	max_width  int = teedy_web_variant_max
	max_height int = teedy_web_variant_max
	quality    int = 85
}

pub struct Variant {
pub:
	mime_type string
	bytes     []u8
	width     int
	height    int
}

pub fn image_variant_for_size(path string, size string) !Variant {
	return match size {
		'web' {
			image_variant_from_disk(path, VariantOptions{
				max_width:  teedy_web_variant_max
				max_height: teedy_web_variant_max
			})
		}
		'thumb' {
			image_variant_from_disk(path, VariantOptions{
				max_width:  teedy_thumb_variant_max
				max_height: teedy_thumb_variant_max
			})
		}
		else {
			error('image variant size must be web or thumb')
		}
	}
}

pub fn placeholder_variant_for_size(size string) !Variant {
	return match size {
		'web' { placeholder_variant(512, 384)! }
		'thumb' { placeholder_variant(teedy_thumb_variant_max, teedy_thumb_variant_max)! }
		else { error('placeholder size must be web or thumb') }
	}
}

pub fn image_variant_from_disk(path string, options VariantOptions) !Variant {
	if path.trim_space() == '' || !os.exists(path) {
		return error('image file not found')
	}
	max_width := clean_max_dimension(options.max_width)
	max_height := clean_max_dimension(options.max_height)
	quality := clean_jpeg_quality(options.quality)
	mut img := stbi.load(path, desired_channels: 4)!
	defer {
		img.free()
	}
	width, height := fit_image_dimensions(img.width, img.height, max_width, max_height)
	if width == img.width && height == img.height {
		return jpeg_variant_from_image(&img, quality)!
	}
	mut resized := stbi.resize_uint8(&img, width, height)!
	defer {
		resized.free()
	}
	return jpeg_variant_from_image(&resized, quality)!
}

fn placeholder_variant(width int, height int) !Variant {
	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			idx := (y * width + x) * 4
			inside := x > width / 6 && x < width * 5 / 6 && y > height / 5 && y < height * 4 / 5
			pixels[idx] = if inside { u8(225) } else { u8(243) }
			pixels[idx + 1] = if inside { u8(231) } else { u8(244) }
			pixels[idx + 2] = if inside { u8(238) } else { u8(246) }
			pixels[idx + 3] = 255
		}
	}
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

fn jpeg_variant_from_image(img &stbi.Image, quality int) !Variant {
	path := temp_variant_path('jpg')
	defer {
		os.rm(path) or {}
	}
	stbi.stbi_write_jpg(path, img.width, img.height, img.nr_channels, img.data, quality)!
	return Variant{
		mime_type: 'image/jpeg'
		bytes:     os.read_bytes(path)!
		width:     img.width
		height:    img.height
	}
}

fn fit_image_dimensions(width int, height int, max_width int, max_height int) (int, int) {
	if width <= 0 || height <= 0 {
		return 1, 1
	}
	scale_w := f64(max_width) / f64(width)
	scale_h := f64(max_height) / f64(height)
	scale := math.min(1.0, math.min(scale_w, scale_h))
	out_width := math.max(1, int(math.round(f64(width) * scale)))
	out_height := math.max(1, int(math.round(f64(height) * scale)))
	return out_width, out_height
}

fn clean_max_dimension(value int) int {
	if value <= 0 {
		return teedy_web_variant_max
	}
	return value
}

fn clean_jpeg_quality(value int) int {
	if value < 1 {
		return 85
	}
	if value > 100 {
		return 100
	}
	return value
}

fn temp_variant_path(ext string) string {
	return os.join_path(os.temp_dir(), 'vfile_thumbnail_${rand.uuid_v4()}.${ext}')
}
