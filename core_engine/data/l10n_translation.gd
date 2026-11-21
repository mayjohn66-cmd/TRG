# File: res://core_engine/data/l10n_translation.gd
# Class: class_name L10nTranslation
# Role: TranslationServer에 붙는 언어별 사전 (locale이 en 또는 ja인 것 하나씩). Label·Button·툴팁처럼 자동 번역되는 노드가 글자를 바꿀 때마다 L10n.translate_text로 바꿔 준다.
#       번역이 없으면 빈 값을 돌려 원문이 그대로 나온다.
class_name L10nTranslation
extends Translation


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	if L10n.current_lang != locale:
		return &""
	var source: String = String(src_message)
	var translated: String = L10n.translate_text(source, locale)
	return StringName(translated) if translated != source else &""


func _get_plural_message(src_message: StringName, _src_plural_message: StringName, _n: int, context: StringName) -> StringName:
	return _get_message(src_message, context)
