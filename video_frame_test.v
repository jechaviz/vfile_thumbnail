module vfile_thumbnail

import os
import stbi
import time

fn test_video_frame_variant_uses_ffmpeg_output_frame() {
	root := os.join_path(os.temp_dir(), 'vfile-thumbnail-video-frame-${time.now().unix_milli()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}
	video_path := os.join_path(root, 'clip.webm')
	os.write_file(video_path, 'fake video bytes')!
	source_png := os.join_path(root, 'frame.png')
	write_frame_test_png(source_png, 4, 2)!
	frame := image_variant_from_disk(source_png, VariantOptions{})!
	frame_path := os.join_path(root, 'frame.jpg')
	os.write_file_array(frame_path, frame.bytes)!
	args_path := os.join_path(root, 'args.txt')
	ffmpeg := build_fake_ffmpeg(root)!
	os.setenv('FAKE_FFMPEG_FRAME', frame_path, true)
	os.setenv('FAKE_FFMPEG_ARGS', args_path, true)
	defer {
		os.unsetenv('FAKE_FFMPEG_FRAME')
		os.unsetenv('FAKE_FFMPEG_ARGS')
	}

	variant := video_frame_variant_for_size(video_path, 'thumb', ffmpeg)!

	assert variant.mime_type == 'image/jpeg'
	assert variant.width == 4
	assert variant.height == 2
	assert variant.bytes[0] == 0xff
	assert variant.bytes[1] == 0xd8
	args := os.read_file(args_path)!
	assert args.contains('-y|-i|${video_path}|-vf|thumbnail|-frames:v|1|-f|mjpeg|')
}

fn test_video_frame_variant_reports_missing_ffmpeg() {
	root := os.join_path(os.temp_dir(),
		'vfile-thumbnail-video-frame-missing-${time.now().unix_milli()}')
	os.rmdir_all(root) or {}
	os.mkdir_all(root)!
	defer {
		os.rmdir_all(root) or {}
	}
	video_path := os.join_path(root, 'clip.mp4')
	os.write_file(video_path, 'fake video bytes')!

	video_frame_variant_for_size(video_path, 'thumb', os.join_path(root, 'missing-ffmpeg.exe')) or {
		assert err.msg().contains('ffmpeg executable not found')
		return
	}
	assert false
}

fn build_fake_ffmpeg(root string) !string {
	source := os.join_path(root, 'fake_ffmpeg.v')
	executable := os.join_path(root, fake_ffmpeg_binary_name())
	os.write_file(source,
		"module main\n\nimport os\n\nfn main() {\n\targs_path := os.getenv('FAKE_FFMPEG_ARGS')\n\tif args_path != '' {\n\t\tos.write_file(args_path, os.args[1..].join('|')) or {}\n\t}\n\tframe_path := os.getenv('FAKE_FFMPEG_FRAME')\n\tbytes := os.read_bytes(frame_path) or {\n\t\teprintln(err.msg())\n\t\texit(4)\n\t}\n\tif os.args.len < 2 {\n\t\texit(5)\n\t}\n\tos.write_file_array(os.args[os.args.len - 1], bytes) or { exit(6) }\n}\n")!
	vexe := frame_vexe_for_tests()!
	result :=
		os.execute('${os.quoted_path(vexe)} -o ${os.quoted_path(executable)} ${os.quoted_path(source)}')
	if result.exit_code != 0 {
		return error('fake ffmpeg build failed: ${result.output}')
	}
	return executable
}

fn fake_ffmpeg_binary_name() string {
	$if windows {
		return 'fake_ffmpeg.exe'
	} $else {
		return 'fake_ffmpeg'
	}
}

fn frame_vexe_for_tests() !string {
	env_value := os.getenv('VEXE').trim_space()
	if env_value != '' {
		return env_value
	}
	$if windows {
		fallback := 'C:\\git\\v\\v.exe'
		if os.exists(fallback) {
			return fallback
		}
	} $else {
		return 'v'
	}
	return error('VEXE is required to build fake ffmpeg')
}

fn write_frame_test_png(path string, width int, height int) ! {
	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			idx := (y * width + x) * 4
			pixels[idx] = u8((x * 60) % 255)
			pixels[idx + 1] = u8((y * 90) % 255)
			pixels[idx + 2] = 160
			pixels[idx + 3] = 255
		}
	}
	stbi.stbi_write_png(path, width, height, 4, pixels.data, width * 4)!
}
