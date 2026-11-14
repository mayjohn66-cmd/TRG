# File: res://tests/test_render_quality.gd
# Class: class_name TestRenderQuality
# Role: 화질 설정의 기본값(터치 기기는 저화질)과 웹 캔버스 해상도 상한 연결 검증
class_name TestRenderQuality
extends TestCase


func test_default_quality_follows_the_device() -> void:
	var saved_touch: bool = MobileSupport.force_touch
	MobileSupport.force_touch = false
	check(not GameSession.default_low_quality(), "PC는 고화질이 기본")
	MobileSupport.force_touch = true
	check(GameSession.default_low_quality(), "터치 기기는 저화질이 기본")
	var saved_low: bool = GameSession.low_quality
	GameSession.reset_settings()
	check(GameSession.low_quality, "기본값으로 되돌리면 터치 기기는 저화질")
	MobileSupport.force_touch = false
	GameSession.reset_settings()
	check(not GameSession.low_quality, "기본값으로 되돌리면 PC는 고화질")
	MobileSupport.force_touch = saved_touch
	GameSession.low_quality = saved_low
	GameSession.save_settings()


func test_render_width_caps() -> void:
	check_eq(GameSession.RENDER_WIDTH_LOW, 1366, "저화질: 기준 해상도")
	check_eq(GameSession.RENDER_WIDTH_HIGH, 2732, "고화질: 기준의 2배")
	GameSession.apply_render_quality()  # 웹이 아니면 아무 일도 없다 (오류 없이 지나간다)
	check(true, "웹이 아니어도 안전하다")


func test_shell_caps_the_canvas_by_the_game_setting() -> void:
	var shell: String = FileAccess.get_file_as_string("res://web/shell.html")
	check(shell.contains("window.trgSetMaxCanvasWidth"), "shell.html이 게임에서 부르는 상한 함수를 연다")
	check(shell.contains("Math.min(d, maxCanvasW / w)"), "캔버스 배율을 상한으로 묶는다")
	check(shell.contains("canvas.width = Math.round(w * d)"), "묶은 배율로 캔버스 크기를 정한다")
