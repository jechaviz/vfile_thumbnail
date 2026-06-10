module vfile_thumbnail

import math.bits

fn test_video_info_reads_webm_codec_and_dimensions() {
	info := video_info_from_webm_bytes(webm_test_file_bytes('V_VP9', 1920, 1080))!
	assert info.container == 'WebM'
	assert info.codec_id == 'V_VP9'
	assert info.codec == 'VP9'
	assert info.width == 1920
	assert info.height == 1080
	assert info.duration_ms == 1250
}

fn test_video_info_prefers_video_track_when_audio_track_follows() {
	info :=
		video_info_from_webm_bytes(webm_test_file_bytes_with_audio('V_VP9', 'A_OPUS', 1920, 1080))!
	assert info.container == 'WebM'
	assert info.codec_id == 'V_VP9'
	assert info.codec == 'VP9'
	assert info.width == 1920
	assert info.height == 1080
	assert info.duration_ms == 1250
}

fn webm_test_file_bytes(codec_id string, width int, height int) []u8 {
	video := ebml_test_element([u8(0xe0)], ebml_test_element([u8(0xb0)], ebml_test_uint(width)) +
		ebml_test_element([u8(0xba)], ebml_test_uint(height)))
	track := ebml_test_element([u8(0xae)], ebml_test_element([u8(0x86)], codec_id.bytes()) + video)
	tracks := ebml_test_element([u8(0x16), 0x54, 0xae, 0x6b], track)
	return ebml_test_element([u8(0x18), 0x53, 0x80, 0x67], webm_test_info() + tracks)
}

fn webm_test_file_bytes_with_audio(video_codec_id string, audio_codec_id string, width int, height int) []u8 {
	video := ebml_test_element([u8(0xe0)], ebml_test_element([u8(0xb0)], ebml_test_uint(width)) +
		ebml_test_element([u8(0xba)], ebml_test_uint(height)))
	video_track := ebml_test_element([u8(0xae)], ebml_test_element([u8(0x83)], ebml_test_uint(1)) +
		ebml_test_element([u8(0x86)], video_codec_id.bytes()) + video)
	audio_track := ebml_test_element([u8(0xae)], ebml_test_element([u8(0x83)], ebml_test_uint(2)) +
		ebml_test_element([u8(0x86)], audio_codec_id.bytes()))
	tracks := ebml_test_element([u8(0x16), 0x54, 0xae, 0x6b], video_track + audio_track)
	return ebml_test_element([u8(0x18), 0x53, 0x80, 0x67], webm_test_info() + tracks)
}

fn webm_test_info() []u8 {
	return ebml_test_element([u8(0x15), 0x49, 0xa9, 0x66],
		ebml_test_element([u8(0x2a), 0xd7, 0xb1], ebml_test_uint(1000000)) +
		ebml_test_element([u8(0x44), 0x89], ebml_test_float64(1250.0)))
}

fn ebml_test_element(id []u8, payload []u8) []u8 {
	mut out := []u8{}
	out << id
	out << ebml_test_size(payload.len)
	out << payload
	return out
}

fn ebml_test_size(size int) []u8 {
	if size < 0x7f {
		return [u8(0x80 | size)]
	}
	return [u8(0x40 | ((size >> 8) & 0x3f)), u8(size & 0xff)]
}

fn ebml_test_uint(value int) []u8 {
	if value <= 0xff {
		return [u8(value)]
	}
	if value <= 0xffffff {
		return [u8((value >> 16) & 0xff), u8((value >> 8) & 0xff), u8(value & 0xff)]
	}
	return [u8((value >> 8) & 0xff), u8(value & 0xff)]
}

fn ebml_test_float64(value f64) []u8 {
	raw := bits.f64_bits(value)
	return [
		u8((raw >> 56) & 0xff),
		u8((raw >> 48) & 0xff),
		u8((raw >> 40) & 0xff),
		u8((raw >> 32) & 0xff),
		u8((raw >> 24) & 0xff),
		u8((raw >> 16) & 0xff),
		u8((raw >> 8) & 0xff),
		u8(raw & 0xff),
	]
}
