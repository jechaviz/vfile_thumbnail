module vfile_thumbnail

import os

fn test_teedy_real_video_fixtures_expose_metadata() {
	webm := teedy_video_fixture_path('video.webm')
	mp4 := teedy_video_fixture_path('video.mp4')
	if webm == '' || mp4 == '' {
		return
	}
	webm_info := video_info_from_disk(webm)!
	assert webm_info.container == 'WebM'
	assert webm_info.codec_id == 'V_VP9'
	assert webm_info.codec == 'VP9'
	assert webm_info.width == 1920
	assert webm_info.height == 1080
	assert webm_info.duration_ms == 1968

	mp4_info := video_info_from_disk(mp4)!
	assert mp4_info.container == 'MP4'
	assert mp4_info.width == 902
	assert mp4_info.height == 720
	assert mp4_info.duration_ms == 968
}

fn teedy_video_fixture_path(name string) string {
	rel := os.join_path('_refs', 'Teedy', 'docs-core', 'src', 'test', 'resources', 'file', name)
	candidates := [
		os.join_path(os.dir(os.getwd()), rel),
		os.join_path('C:\\git\\v_projects', rel),
	]
	for candidate in candidates {
		if os.exists(candidate) {
			return candidate
		}
	}
	return ''
}
