# File: res://core_engine/emote_catalog.gd
# Class: class_name EmoteCatalog
# Role: 감정 표현(이모트) 목록. 이모트 하나 = 얼굴 그림 종류(EmoteFace가 코드로 그린다) + 말풍선 문구 + 아바타 감정(AvatarSlot.Emotion 번호). 온라인은 번호만 주고받는다 (NetGame.send_emote)
#       게임 글꼴(ONE Mobile POP + 나눔고딕)에는 이모지가 없어 웹에서 깨지므로 이모지 문자를 쓰지 않는다
class_name EmoteCatalog
extends RefCounted

## 아바타 감정 번호 (AvatarSlot.Emotion과 같은 값: 1 웃음 / 2 분노 / 3 놀람 / 4 낙담 / 5 환호).
const HAPPY: int = 1
const ANGRY: int = 2
const SURPRISED: int = 3
const SAD: int = 4
const CHEER: int = 5

## 3종: 버튼에는 감정 이름(label), 말풍선에는 한마디(text).
const EMOTES: Array[Dictionary] = [
	{"face": &"joy", "label": "기쁨", "text": "야호!", "emotion": CHEER, "color": Color("2f9e44")},
	{"face": &"flustered", "label": "당황", "text": "어라라?!", "emotion": SURPRISED, "color": Color("1971c2")},
	{"face": &"sad", "label": "슬픔", "text": "흑흑…", "emotion": SAD, "color": Color("5f6b7a")},
]


static func count() -> int:
	return EMOTES.size()


static func is_valid(emote_id: int) -> bool:
	return emote_id >= 0 and emote_id < EMOTES.size()


static func entry(emote_id: int) -> Dictionary:
	return EMOTES[clampi(emote_id, 0, EMOTES.size() - 1)]
