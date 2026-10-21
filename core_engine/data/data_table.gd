# File: res://core_engine/data/data_table.gd
# Class: class_name DataTable
# Role: 엑셀·스프레드시트·텍스트 에디터로 고치는 CSV 밸런스 표를 읽는 순수 텍스트 파서. Godot의 CSV 번역 임포터를 거치지 않고 FileAccess로 직접 읽는다 (.csv.import는 importer="keep")
class_name DataTable
extends RefCounted


## CSV 본문을 [{헤더: 값}, ...]로 바꾼다. 큰따옴표 필드(쉼표·줄바꿈·"" 이스케이프)를 지원하고, UTF-8 BOM과 빈 줄은 무시한다. 필드 안의 글자 그대로의 \n(역슬래시 n)은 줄바꿈이 된다.
static func parse(text: String) -> Array[Dictionary]:
	var rows: Array[Array] = _split_records(text)
	var result: Array[Dictionary] = []
	if rows.is_empty():
		return result
	var header: Array = rows[0]
	for index: int in range(1, rows.size()):
		var record: Array = rows[index]
		var row: Dictionary = {}
		for column: int in header.size():
			var key: String = str(header[column]).strip_edges()
			if key == "":
				continue
			row[key] = str(record[column]).replace("\\n", "\n") if column < record.size() else ""
		result.append(row)
	return result


## 파일을 읽어 파싱한다. 파일이 없거나 비어 있으면 빈 배열이다 (호출한 쪽이 코드 기본값으로 대체한다).
static func load_file(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		return [] as Array[Dictionary]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return [] as Array[Dictionary]
	return parse(file.get_as_text())


## 헤더 이름 목록 (무결성 검사용).
static func header_of(text: String) -> Array[String]:
	var rows: Array[Array] = _split_records(text)
	var names: Array[String] = []
	if rows.is_empty():
		return names
	for name: Variant in rows[0]:
		names.append(str(name).strip_edges())
	return names


static func to_bool(value: Variant, default: bool = true) -> bool:
	var text: String = str(value).strip_edges().to_upper()
	if text == "TRUE" or text == "1" or text == "YES" or text == "Y" or text == "O":
		return true
	if text == "FALSE" or text == "0" or text == "NO" or text == "N" or text == "X":
		return false
	return default


## "+3"·" 5 "·"3.0" 같은 값을 정수로 읽는다. 비어 있거나 숫자가 아니면 default.
static func to_int(value: Variant, default: int) -> int:
	var text: String = str(value).strip_edges().trim_prefix("+")
	if text == "" or not (text.is_valid_int() or text.is_valid_float()):
		return default
	return int(text.to_float())


static func _split_records(text: String) -> Array[Array]:
	# BOM은 글자 코드로 비교한다. 소스에 BOM 글자를 그대로 적으면 웹 내보내기가 스크립트를 변환하며 그 글자를 지워
	# begins_with("")가 되어 늘 참이 되고, 모든 CSV의 첫 글자(헤더 "id"의 i)가 잘려 표 전체가 무시됐다.
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var records: Array[Array] = []
	var record: Array = []
	var field: String = ""
	var quoted: bool = false
	var index: int = 0
	var length: int = text.length()
	while index < length:
		var ch: String = text[index]
		if quoted:
			if ch == "\"":
				if index + 1 < length and text[index + 1] == "\"":
					field += "\""
					index += 1
				else:
					quoted = false
			else:
				field += ch
		elif ch == "\"":
			quoted = true
		elif ch == ",":
			record.append(field)
			field = ""
		elif ch == "\r":
			pass
		elif ch == "\n":
			record.append(field)
			field = ""
			_push_record(records, record)
			record = []
		else:
			field += ch
		index += 1
	if field != "" or not record.is_empty():
		record.append(field)
		_push_record(records, record)
	return records


static func _push_record(records: Array[Array], record: Array) -> void:
	if record.size() == 1 and str(record[0]).strip_edges() == "":
		return  # 빈 줄
	records.append(record)
