# File: res://tests/test_update_notes.gd
# Class: class_name TestUpdateNotes
# Role: 로비 [업데이트 소식] 버튼의 내용 검사 - patch_notes.json의 모든 글이 ko/en/ja로 채워져 있는지, 새 소식 [N] 표시가 본 id를 저장해 꺼지는지, 언어 폴백
class_name TestUpdateNotes
extends TestCase

const PATH: String = "user://test_update_notes_save.json"

var _saved_path: String = ""
var _saved_browser: bool = false


func _setup_save() -> void:
	_saved_path = PlayerSave.storage_path
	_saved_browser = PlayerSave.use_browser
	PlayerSave.storage_path = PATH
	PlayerSave.use_browser = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	PlayerSave.reset_cache()


func _restore_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	PlayerSave.storage_path = _saved_path
	PlayerSave.use_browser = _saved_browser
	PlayerSave.reset_cache()


func _texts(entry: Dictionary) -> Array:
	var found: Array = [entry.get("title")]
	for section: Dictionary in entry.get("sections", []):
		found.append(section.get("head"))
		found.append_array(section.get("items", []))
	return found


func test_every_note_has_korean_english_and_japanese_text() -> void:
	var all: Array = UpdateNotes.entries()
	check(not all.is_empty(), "소식 항목이 있다")
	check(UpdateNotes.latest_id() != "", "맨 앞 항목에 id가 있다")
	var seen_ids: Dictionary = {}
	for entry: Dictionary in all:
		var id: String = str(entry.get("id", ""))
		check(id != "" and not seen_ids.has(id), "id %s는 비어 있지 않고 겹치지 않는다" % id)
		seen_ids[id] = true
		for node: Variant in _texts(entry):
			var map: Dictionary = node as Dictionary
			check(map != null and not map.is_empty(), "%s: 글 묶음이 비어 있지 않다" % id)
			for lang: String in ["ko", "en", "ja"]:
				check(map != null and str(map.get(lang, "")).strip_edges() != "", "%s: %s 글이 채워져 있다 (%s)" % [id, lang, str(map.get("ko", ""))])


func test_new_badge_turns_off_once_opened_and_returns_for_a_new_id() -> void:
	_setup_save()
	check(UpdateNotes.has_unseen(), "처음에는 새 소식 표시가 켜진다")
	UpdateNotes.mark_seen()
	check(not UpdateNotes.has_unseen(), "열어 본 뒤에는 꺼진다")
	PlayerSave.reset_cache()  # 새로고침해도 저장돼 있다
	check(not UpdateNotes.has_unseen(), "다시 접속해도 꺼져 있다")
	PlayerSave.set_value(UpdateNotes.SEEN_KEY, "0.9")  # 옛 버전을 본 사람
	check(UpdateNotes.has_unseen(), "새 id가 나오면 다시 켜진다")
	_restore_save()


func test_text_picks_the_current_language_and_falls_back_to_korean() -> void:
	var saved: String = L10n.current_lang
	var node: Dictionary = {"ko": "한글", "en": "English", "ja": ""}
	L10n.current_lang = "en"
	check_eq(UpdateNotes.pick(node), "English", "영어")
	L10n.current_lang = "ja"
	check_eq(UpdateNotes.pick(node), "한글", "일본어 글이 비면 한국어")
	L10n.current_lang = saved


func test_popup_shows_one_version_at_a_time_with_tabs() -> void:
	_setup_save()
	var parent := Control.new()
	defer_free(parent)
	var popup: Control = UpdateNotes.open(parent)
	var tabs: Array = popup.find_children("NotesTab*", "Button", true, false)
	check_eq(tabs.size(), UpdateNotes.entries().size(), "버전마다 탭 하나")
	check_eq(popup.find_children("NotesTitle", "Label", true, false).size(), 1, "처음엔 한 버전만 보인다")
	var first_title: String = (popup.find_children("NotesTitle", "Label", true, false)[0] as Label).text
	check(first_title.contains(UpdateNotes.pick((UpdateNotes.entries()[0] as Dictionary).get("title"))), "처음엔 최신 버전")
	if tabs.size() >= 2:
		(tabs[1] as Button).pressed.emit()
		var list: Node = popup.find_child("NotesList", true, false)
		for child: Node in list.get_children():
			if child.is_queued_for_deletion():
				list.remove_child(child)
		var second: String = (popup.find_children("NotesTitle", "Label", true, false)[0] as Label).text
		check(second.contains(UpdateNotes.pick((UpdateNotes.entries()[1] as Dictionary).get("title"))), "두 번째 탭을 누르면 그 버전이 보인다")
		check_eq(popup.find_children("NotesTitle", "Label", true, false).size(), 1, "여전히 한 버전만")
	popup.queue_free()
	_restore_save()
