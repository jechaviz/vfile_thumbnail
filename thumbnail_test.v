module vfile_thumbnail

import os
import stbi

fn test_image_variant_resizes_to_requested_box() {
	root := os.join_path(os.temp_dir(), 'vfile-thumbnail-variant-${os.getpid()}')
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}
	source := os.join_path(root, 'source.png')
	write_test_png(source, 4, 2)!

	variant := image_variant_from_disk(source, VariantOptions{
		max_width:  2
		max_height: 2
	})!

	assert variant.mime_type == 'image/jpeg'
	assert variant.width == 2
	assert variant.height == 1
	assert variant.bytes.len > 0
	assert variant.bytes[0] == 0xff
	assert variant.bytes[1] == 0xd8
}

fn test_image_variant_does_not_upscale_small_images() {
	root := os.join_path(os.temp_dir(), 'vfile-thumbnail-small-${os.getpid()}')
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}
	source := os.join_path(root, 'small.png')
	write_test_png(source, 2, 3)!

	variant := image_variant_for_size(source, 'thumb')!

	assert variant.width == 2
	assert variant.height == 3
	assert variant.mime_type == 'image/jpeg'
}

fn test_image_info_reads_source_dimensions() {
	root := os.join_path(os.temp_dir(), 'vfile-thumbnail-info-${os.getpid()}')
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}
	source := os.join_path(root, 'info.png')
	write_test_png(source, 7, 5)!

	info := image_info_from_disk(source)!

	assert info.width == 7
	assert info.height == 5
}

fn test_placeholder_variant_is_png() {
	variant := placeholder_variant_for_size('thumb')!

	assert variant.mime_type == 'image/png'
	assert variant.width == teedy_thumb_variant_max
	assert variant.height == teedy_thumb_variant_max
	assert variant.bytes.len > 8
	assert variant.bytes[0] == 0x89
	assert variant.bytes[1] == 0x50
}

fn test_video_placeholder_variant_uses_teedy_sizes() {
	thumb := video_placeholder_variant_for_size('thumb')!
	web := video_placeholder_variant_for_size('web')!

	assert thumb.mime_type == 'image/png'
	assert thumb.width == teedy_thumb_variant_max
	assert thumb.height == teedy_thumb_variant_max
	assert web.mime_type == 'image/png'
	assert web.width == 512
	assert web.height == 288
}

fn test_video_placeholder_variant_uses_source_aspect_ratio() {
	thumb := video_placeholder_variant_for_size_with_dimensions('thumb', 720, 1280)!
	web := video_placeholder_variant_for_size_with_dimensions('web', 720, 1280)!
	assert thumb.width == 144
	assert thumb.height == 256
	assert web.width == 288
	assert web.height == 512
}

fn test_video_info_reads_mp4_track_header_dimensions() {
	info := video_info_from_mp4_bytes(mp4_test_file_bytes(720, 1280))!
	assert info.width == 720
	assert info.height == 1280
	assert info.duration_ms == 1250
}

fn test_text_variant_renders_jpeg_document_preview() {
	variant := text_variant_for_size(TextVariantInput{
		name: 'notes.txt'
		text: 'Line one\nLine two with punctuation: ok!'
	}, 'thumb')!

	assert variant.mime_type == 'image/jpeg'
	assert variant.width == 192
	assert variant.height == 256
	assert variant.bytes.len > 0
	assert variant.bytes[0] == 0xff
	assert variant.bytes[1] == 0xd8
}

fn write_test_png(path string, width int, height int) ! {
	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			idx := (y * width + x) * 4
			pixels[idx] = u8((x * 60) % 255)
			pixels[idx + 1] = u8((y * 80) % 255)
			pixels[idx + 2] = 180
			pixels[idx + 3] = 255
		}
	}
	stbi.stbi_write_png(path, width, height, 4, pixels.data, width * 4)!
}

fn mp4_test_file_bytes(width int, height int) []u8 {
	return mp4_test_box('ftyp', 'isom'.bytes()) + mp4_test_box('moov', mp4_test_mvhd(1000, 1250) +
		mp4_test_box('trak', mp4_test_tkhd(width, height)))
}

fn mp4_test_mvhd(timescale int, duration int) []u8 {
	mut payload := []u8{len: 24}
	write_test_be_u32(mut payload, 12, u32(timescale))
	write_test_be_u32(mut payload, 16, u32(duration))
	return mp4_test_box('mvhd', payload)
}

fn mp4_test_tkhd(width int, height int) []u8 {
	mut payload := []u8{len: 84}
	write_test_be_u32(mut payload, 76, u32(width) << 16)
	write_test_be_u32(mut payload, 80, u32(height) << 16)
	return mp4_test_box('tkhd', payload)
}

fn mp4_test_box(kind string, payload []u8) []u8 {
	mut out := []u8{}
	append_test_be_u32(mut out, u32(payload.len + 8))
	out << kind.bytes()[..4]
	out << payload
	return out
}

fn append_test_be_u32(mut out []u8, value u32) {
	out << u8(value >> 24)
	out << u8((value >> 16) & 0xff)
	out << u8((value >> 8) & 0xff)
	out << u8(value & 0xff)
}

fn write_test_be_u32(mut out []u8, at int, value u32) {
	out[at] = u8(value >> 24)
	out[at + 1] = u8((value >> 16) & 0xff)
	out[at + 2] = u8((value >> 8) & 0xff)
	out[at + 3] = u8(value & 0xff)
}
