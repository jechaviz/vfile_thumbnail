module vfile_thumbnail

import os

const max_video_probe_bytes = 64 * 1024 * 1024

pub struct VideoInfo {
pub:
	width  int
	height int
}

pub fn video_info_from_disk(path string) !VideoInfo {
	if path.trim_space() == '' || !os.exists(path) {
		return error('video file not found')
	}
	if os.file_size(path) > u64(max_video_probe_bytes) {
		return error('video metadata probe exceeds limit')
	}
	return video_info_from_mp4_bytes(os.read_bytes(path)!)!
}

fn video_info_from_mp4_bytes(data []u8) !VideoInfo {
	info := video_info_from_mp4_boxes(data, 0, data.len, 0) or {
		return error('video dimensions not found')
	}
	return info
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
