# File: res://tests/hangul_scan.gd
# Class: class_name HangulScan
# Role: 영어 화면 검사 도구. 보이는 노드가 "실제로 화면에 그리는 글자"(자동 번역을 거친 글자)를 모아 한글이 남은 곳을 찾는다.
#       Label·Button·RichTextLabel·LineEdit 안내문·OptionButton 항목·툴팁·Label3D를 본다. 직접 그리는 글자(draw_string)는 L10n.t를 거치도록 고쳐 두었다.
class_name HangulScan
extends RefCounted

## 영어 화면에도 그대로 두는 한국어 (언어 목록의 "한국어").
const ALLOWED: Array[String] = ["한국어"]


## root 아래 보이는 노드에서 한글이 남은 글자를 찾는다. 반환: {"노드 경로 | 글자": true}
static func scan(root: Node, found: Dictionary = {}) -> Dictionary:
	_walk(root, found)
	return found


static func _walk(node: Node, found: Dictionary) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return
	for text: String in displayed_texts(node):
		if L10n.has_hangul(text) and not ALLOWED.has(text.strip_edges()):
			var short: String = text.replace("\n", "⏎")
			found["%s | %s" % [_path(node), short.substr(0, 160)]] = true
	for child: Node in node.get_children():
		_walk(child, found)


## 이 노드가 화면에 그리는 글자들.
static func displayed_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is RichTextLabel:
		texts.append((node as RichTextLabel).get_parsed_text())
	elif node is Label or node is Button or node is Label3D:
		texts.append(_shown(node, str(node.get("text"))))
	if node is LineEdit:
		texts.append(_shown(node, (node as LineEdit).placeholder_text))
	if node is OptionButton:
		var option := node as OptionButton
		for index: int in option.item_count:
			var item: String = option.get_item_text(index)
			if not ALLOWED.has(item.get_slice(" (", 0)):
				texts.append(_shown(node, item))
	if node is Control and (node as Control).tooltip_text != "":
		texts.append(_shown(node, (node as Control).tooltip_text))
	return texts


static func _shown(node: Node, text: String) -> String:
	if text == "":
		return text
	return node.atr(text) if node.can_auto_translate() else text


static func _path(node: Node) -> String:
	var parts: PackedStringArray = []
	var cursor: Node = node
	while cursor != null and parts.size() < 4:
		parts.insert(0, String(cursor.name))
		cursor = cursor.get_parent()
	return "/".join(parts)
