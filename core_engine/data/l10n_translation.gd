# File: res://core_engine/data/l10n_translation.gd
# Class: class_name L10nTranslation
# Role: TranslationServer에 붙는 영어 사전. Label·Button·툴팁처럼 자동 번역되는 노드가 글자를 바꿀 때마다 L10n.translate_text로 바꿔 준다.
#       번역이 없으면 빈 값을 돌려 원문이 그대로 나온다.
class_name L10nTranslation
extends Translation


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	if L10n.current_lang != "en":
		return &""
	var source: String = String(src_message)
	var translated: String = L10n.translate_text(source, "en")
	return StringName(translated) if translated != source else &""


func _get_plural_message(src_message: StringName, _src_plural_message: StringName, _n: int, context: StringName) -> StringName:
	return _get_message(src_message, context)
