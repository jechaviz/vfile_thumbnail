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
