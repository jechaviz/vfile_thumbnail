module vfile_thumbnail

import os

const default_ffmpeg_command = 'ffmpeg'

pub fn video_frame_variant_for_size(path string, size string, ffmpeg_path string) !Variant {
	frame_path := extract_video_frame_jpeg(path, ffmpeg_path)!
	defer {
		os.rm(frame_path) or {}
	}
	return image_variant_for_size(frame_path, size)
}

fn extract_video_frame_jpeg(path string, ffmpeg_path string) !string {
	if path.trim_space() == '' || !os.exists(path) {
		return error('video file not found')
	}
	executable := resolved_ffmpeg_executable(ffmpeg_path)!
	frame_path := temp_variant_path('jpg')
	mut process := os.new_process(executable)
	process.set_args(['-y', '-i', path, '-vf', 'thumbnail', '-frames:v', '1', '-f', 'mjpeg',
		frame_path])
	process.set_redirect_stdio()
	process.wait()
	_ := process.stdout_slurp()
	stderr := process.stderr_slurp().trim_space()
	code := process.code
	process.close()
	if code != 0 {
		os.rm(frame_path) or {}
		detail := if stderr == '' { 'exit code ${code}' } else { stderr }
		return error('ffmpeg video thumbnail failed: ${detail}')
	}
	if !os.exists(frame_path) || os.file_size(frame_path) == 0 {
		os.rm(frame_path) or {}
		return error('ffmpeg video thumbnail returned no frame')
	}
	return frame_path
}

fn resolved_ffmpeg_executable(value string) !string {
	clean := value.trim_space()
	if clean != '' {
		return resolve_executable(clean, 'ffmpeg')!
	}
	env_value := os.getenv('VFILE_FFMPEG_PATH').trim_space()
	if env_value != '' {
		return resolve_executable(env_value, 'ffmpeg')!
	}
	return resolve_executable(default_ffmpeg_command, 'ffmpeg')!
}

fn resolve_executable(value string, label string) !string {
	if looks_like_executable_path(value) {
		if os.exists(value) {
			return value
		}
		return error('${label} executable not found: ${value}')
	}
	return os.find_abs_path_of_executable(value) or {
		return error('${label} executable not found: ${value}')
	}
}

fn looks_like_executable_path(value string) bool {
	return value.contains('/') || value.contains('\\') || value.contains(':')
}
