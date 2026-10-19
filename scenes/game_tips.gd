# File: res://scenes/game_tips.gd
# Class: class_name GameTips
# Role: 로딩·오프닝 화면에 한 줄씩 보여 주는 랜덤 게임 팁 문구 모음 (웹 스플래시 web/shell.html의 TIPS와 같은 내용)
class_name GameTips
extends RefCounted

const TIPS: Array[String] = [
	"윷말끼리 만나면 자동으로 업혀 한 번에 이동해요.",
	"카드는 내 턴 굴리기 전에 턴당 1장만 낼 수 있어요.",
	"카드를 보드판 위로 드래그해서 놓으면 발동해요.",
	"필살기는 기물마다 게임당 1회, 내 프로필 카드에서 눌러요.",
	"점프 코너에 정확히 멈추면 앞으로 껑충 뛰어요. ⚡ 부스터 발판에 멈추면 +3칸!",
	"3라운드마다 증강을 골라 기물·판정 도구·교칙을 바꿔요.",
	"중앙 법전은 4칸! 새 교칙이 들어오면 가장 오래된 교칙이 밀려나요.",
	"뱅! 카드는 상대 프로필을 눌러 선두 말을 출발선으로 날려 버려요.",
]


static func random_tip() -> String:
	return TIPS[randi() % TIPS.size()]
