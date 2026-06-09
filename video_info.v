module vfile_thumbnail

import os

const max_video_probe_bytes = 64 * 1024 * 1024

pub struct VideoInfo {
pub:
	width     int
	height    int
	container string
	codec_id  string
	codec     string
}

pub fn video_info_from_disk(path string) !VideoInfo {
	if path.trim_space() == '' || !os.exists(path) {
		return error('video file not found')
	}
	if os.file_size(path) > u64(max_video_probe_bytes) {
		return error('video metadata probe exceeds limit')
	}
	data := os.read_bytes(path)!
	return video_info_from_bytes(data)!
}

fn video_info_from_bytes(data []u8) !VideoInfo {
	return video_info_from_mp4_bytes(data) or { video_info_from_webm_bytes(data)! }
}

fn video_info_from_mp4_bytes(data []u8) !VideoInfo {
	info := video_info_from_mp4_boxes(data, 0, data.len, 0) or {
		return error('video dimensions not found')
	}
	return VideoInfo{
		width:     info.width
		height:    info.height
		container: 'MP4'
		codec_id:  info.codec_id
		codec:     info.codec
	}
}

fn video_info_from_mp4_boxes(data []u8, start int, end int, depth int) ?VideoInfo {
	if depth > 8 || start < 0 || end > data.len || start >= end {
		return none
	}
	mut i := start
	for i + 8 <= end {
		box_size, header_size := mp4_box_size(data, i, end) or { break }
		if box_size < header_size || i + box_size > end {
			break
		}
		kind := data[i + 4..i + 8].bytestr()
		payload_start := i + header_size
		payload_end := i + box_size
		if kind == 'tkhd' {
			if info := video_info_from_tkhd(data[payload_start..payload_end]) {
				return info
			}
		}
		if kind in ['moov', 'trak', 'edts', 'mdia', 'minf', 'stbl'] {
			if info := video_info_from_mp4_boxes(data, payload_start, payload_end, depth + 1) {
				return info
			}
		}
		i += box_size
	}
	return none
}

fn mp4_box_size(data []u8, start int, end int) ?(int, int) {
	if start + 8 > end {
		return none
	}
	size32 := be_u32(data, start)
	if size32 == 0 {
		return end - start, 8
	}
	if size32 == 1 {
		if start + 16 > end {
			return none
		}
		size64 := be_u64(data, start + 8)
		if size64 > u64(end - start) {
			return none
		}
		return int(size64), 16
	}
	return int(size32), 8
}

fn video_info_from_tkhd(payload []u8) ?VideoInfo {
	if payload.len < 84 {
		return none
	}
	version := payload[0]
	width_at := if version == 1 { 88 } else { 76 }
	height_at := width_at + 4
	if height_at + 4 > payload.len {
		return none
	}
	width := fixed_16_16_to_int(be_u32(payload, width_at))
	height := fixed_16_16_to_int(be_u32(payload, height_at))
	if width <= 0 || height <= 0 {
		return none
	}
	return VideoInfo{
		width:  width
		height: height
	}
}

struct WebmProbe {
mut:
	width       int
	height      int
	codec_id    string
	found_video bool
	found_any   bool
}

struct WebmTrackProbe {
mut:
	width      int
	height     int
	codec_id   string
	track_type int
}

struct EbmlElement {
	id            u64
	payload_start int
	payload_end   int
	next          int
}

fn video_info_from_webm_bytes(data []u8) !VideoInfo {
	mut probe := WebmProbe{}
	webm_probe_range(data, 0, data.len, 0, mut probe)
	if probe.width <= 0 && probe.height <= 0 && probe.codec_id == '' {
		return error('WebM metadata not found')
	}
	return VideoInfo{
		width:     probe.width
		height:    probe.height
		container: 'WebM'
		codec_id:  probe.codec_id
		codec:     video_codec_label(probe.codec_id)
	}
}

fn webm_probe_range(data []u8, start int, end int, depth int, mut probe WebmProbe) {
	if depth > 12 || start < 0 || end > data.len || start >= end {
		return
	}
	mut i := start
	for i < end {
		element := read_ebml_element(data, i, end) or { break }
		match element.id {
			0xae {
				mut track := WebmTrackProbe{}
				webm_track_probe_range(data, element.payload_start, element.payload_end, depth + 1, mut
					track)
				probe.apply_track(track)
			}
			0x86 {
				if !probe.found_video && probe.codec_id == '' {
					probe.codec_id =
						read_ebml_text(data[element.payload_start..element.payload_end])
					probe.found_any = true
				}
			}
			0xb0 {
				if !probe.found_video {
					probe.width = int(read_ebml_uint(data[element.payload_start..element.payload_end]))
					probe.found_any = true
				}
			}
			0xba {
				if !probe.found_video {
					probe.height = int(read_ebml_uint(data[element.payload_start..element.payload_end]))
					probe.found_any = true
				}
			}
			0x18538067, 0x1654ae6b, 0xe0, 0x1549a966 {
				webm_probe_range(data, element.payload_start, element.payload_end, depth + 1, mut
					probe)
			}
			else {}
		}

		i = element.next
	}
}

fn webm_track_probe_range(data []u8, start int, end int, depth int, mut track WebmTrackProbe) {
	if depth > 12 || start < 0 || end > data.len || start >= end {
		return
	}
	mut i := start
	for i < end {
		element := read_ebml_element(data, i, end) or { break }
		match element.id {
			0x83 {
				track.track_type = int(read_ebml_uint(data[element.payload_start..element.payload_end]))
			}
			0x86 {
				track.codec_id = read_ebml_text(data[element.payload_start..element.payload_end])
			}
			0xb0 {
				track.width = int(read_ebml_uint(data[element.payload_start..element.payload_end]))
			}
			0xba {
				track.height = int(read_ebml_uint(data[element.payload_start..element.payload_end]))
			}
			0xe0, 0xe1 {
				webm_track_probe_range(data, element.payload_start, element.payload_end, depth + 1, mut
					track)
			}
			else {}
		}

		i = element.next
	}
}

fn (mut probe WebmProbe) apply_track(track WebmTrackProbe) {
	if !track.has_data() {
		return
	}
	if track.is_video_candidate() {
		if !probe.found_video {
			probe.width = track.width
			probe.height = track.height
			probe.codec_id = track.codec_id
			probe.found_video = true
			probe.found_any = true
		}
		return
	}
	if !probe.found_video && !probe.found_any {
		probe.width = track.width
		probe.height = track.height
		probe.codec_id = track.codec_id
		probe.found_any = true
	}
}

fn (track WebmTrackProbe) has_data() bool {
	return track.width > 0 || track.height > 0 || track.codec_id.trim_space() != ''
}

fn (track WebmTrackProbe) is_video_candidate() bool {
	codec := track.codec_id.trim_space().to_upper()
	return track.track_type == 1 || track.width > 0 || track.height > 0 || codec.starts_with('V_')
}

fn read_ebml_element(data []u8, start int, end int) ?EbmlElement {
	id, id_len := read_ebml_vint(data, start, end, true) or { return none }
	size, size_len := read_ebml_vint(data, start + id_len, end, false) or { return none }
	payload_start := start + id_len + size_len
	if size > u64(end - payload_start) {
		return none
	}
	payload_end := payload_start + int(size)
	return EbmlElement{
		id:            id
		payload_start: payload_start
		payload_end:   payload_end
		next:          payload_end
	}
}

fn read_ebml_vint(data []u8, start int, end int, keep_marker bool) ?(u64, int) {
	if start >= end {
		return none
	}
	first := data[start]
	if first == 0 {
		return none
	}
	mut mask := u8(0x80)
	mut length := 1
	for length <= 8 && (first & mask) == 0 {
		mask >>= 1
		length++
	}
	if length > 8 || start + length > end {
		return none
	}
	mut value := if keep_marker { u64(first) } else { u64(first & (mask - 1)) }
	for offset in 1 .. length {
		value = (value << 8) | u64(data[start + offset])
	}
	return value, length
}

fn read_ebml_uint(bytes []u8) u64 {
	mut value := u64(0)
	for byte in bytes {
		value = (value << 8) | u64(byte)
	}
	return value
}

fn read_ebml_text(bytes []u8) string {
	mut out := []u8{}
	for byte in bytes {
		if byte == 0 {
			break
		}
		out << byte
	}
	return out.bytestr().trim_space()
}

fn video_codec_label(codec_id string) string {
	clean := codec_id.trim_space().to_upper()
	return match clean {
		'V_VP9' { 'VP9' }
		'V_VP8' { 'VP8' }
		'V_AV1' { 'AV1' }
		'V_MPEG4/ISO/AVC' { 'H.264 AVC' }
		'V_MPEGH/ISO/HEVC' { 'H.265 HEVC' }
		else { codec_id.trim_space() }
	}
}

fn fixed_16_16_to_int(value u32) int {
	whole := int(value >> 16)
	fraction := int(value & 0xffff)
	if fraction >= 0x8000 {
		return whole + 1
	}
	return whole
}

fn be_u32(data []u8, start int) u32 {
	return (u32(data[start]) << 24) | (u32(data[start + 1]) << 16) | (u32(data[start + 2]) << 8) | u32(data[
		start + 3])
}

fn be_u64(data []u8, start int) u64 {
	return (u64(be_u32(data, start)) << 32) | u64(be_u32(data, start + 4))
}
