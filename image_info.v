module vfile_thumbnail

import os
import stbi

pub struct ImageInfo {
pub:
	width  int
	height int
}

pub fn image_info_from_disk(path string) !ImageInfo {
	if path.trim_space() == '' || !os.exists(path) {
		return error('image file not found')
	}
	mut img := stbi.load(path, desired_channels: 4)!
	defer {
		img.free()
	}
	return ImageInfo{
		width:  img.width
		height: img.height
	}
}
