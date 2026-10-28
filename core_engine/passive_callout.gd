# File: res://core_engine/passive_callout.gd
# Class: class_name PassiveCallout
# Role: 기물 고유 능력이 발동했을 때 보드 위 그 말 머리에 띄우는 원인 뱃지 문구 ("[나이트] 함정 관통!").
#       엔진은 GameState.passive_triggered(pawn_id, 키)만 알리고, 화면은 이 표에서 문구를 꺼낸다. 영어·일본어는 translations.csv.
class_name PassiveCallout
extends RefCounted

## 키 -> 한국어 문구 ([기물] 원인!). 길이는 한 줄로 읽히게 짧게.
const TEXTS: Dictionary = {
	&"queen_bonus": "[퀸] 이동 +2칸!",
	&"black_odd": "[흑돌] 홀수 눈금 +1칸!",
	&"nari_bonus": "[나리 승급] 이동 +2칸!",
	&"straight_cha": "[장기:차] 직진 +2칸!",
	&"knight_corner": "[나이트] 코너 도약 +2칸!",
	&"plane_card": "[비행기] 옷장 카드+1!",
	&"knight_guard": "[나이트] 맹세 방어!",
	&"straight_rook": "[룩] 직진 +2칸!",
	&"straight_hisha": "[비차] 직진 +2칸!",
	&"straight_ryuo": "[용왕] 직진 +2칸!",
	&"corner_kaku": "[각행] 코너 스침 +2칸!",
	&"corner_ryuma": "[용마] 코너 스침 +3칸!",
	&"bishop_corner": "[비숍] 코너 진입 +1칸!",
	&"po_jump": "[장기:포] 뛰어넘기 +3칸!",
	&"ma_leap": "[장기:마] 빈칸 도약 +2칸!",
	&"sang_leap": "[장기:상] 빈칸 도약 +2칸!",
	&"kart_follow": "[스타 카트] 추가 이동 +2칸!",
	&"ludo_revenge": "[루도 복수자] 복수 질주 +4칸!",
	&"knight_pass": "[나이트] 함정 관통!",
	&"queen_pass": "[퀸] 함정 관통!",
	&"keima_pass": "[계마] 함정 관통!",
	&"kart_immune": "[스타 카트] 함정 면역!",
	&"sweeper_defuse": "[지뢰찾기 공병] 함정 해체 카드+1!",
	&"checker_slide": "[킹 체커] 스침 처치!",
	&"shield_block": "[백돌] 보호막 방어!",
	&"dog_bakery": "[강아지] 빵집 스침 카드+1!",
	&"ship_sink": "[증기선] 설치물 파괴!",
	&"car_salary": "[미니카] 반환점 카드+1!",
	&"plane_warp": "[비행기] 옷장 장거리 워프!",
	&"yut_reroll": "[윷말] 처치 재굴림 +1!",
	&"stack_magnet": "[업기] 옆 칸 아군과 합류!",
}
## 뱃지 테두리 색: 이동 보너스(노랑) / 방어·면역(하늘) / 처치(빨강) / 카드(초록) / 승급·워프(보라).
const COLORS: Dictionary = {
	&"checker_slide": Color("ff6b6b"),
	&"shield_block": Color("74c0fc"), &"kart_immune": Color("74c0fc"), &"knight_pass": Color("74c0fc"), &"queen_pass": Color("74c0fc"), &"keima_pass": Color("74c0fc"), &"ship_sink": Color("74c0fc"),
	&"dog_bakery": Color("8ce99a"), &"car_salary": Color("8ce99a"), &"sweeper_defuse": Color("8ce99a"), &"yut_reroll": Color("8ce99a"),
	&"plane_warp": Color("b197fc"), &"plane_card": Color("8ce99a"), &"knight_guard": Color("74c0fc"), &"stack_magnet": Color("b197fc"),
}


static func text(passive: StringName) -> String:
	return str(TEXTS.get(passive, ""))


static func color(passive: StringName) -> Color:
	return COLORS.get(passive, Color("ffd43b"))
