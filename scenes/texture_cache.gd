# File: res://scenes/texture_cache.gd
# Class: class_name TextureCache
# Role: 전역 텍스처 캐시. 같은 경로의 그림은 한 번만 불러와 재사용한다 (웹 WASM 힙은 한 번 커지면 줄지 않으므로
#       큰 그림을 띄울 때마다 다시 풀고 버리는 일을 막는다). 가로·세로가 MAX_SOURCE_SIZE를 넘는 초고해상도 그림은
#       처음 캐시할 때 한 번만 RESIZE_TO 이하로 줄여 둔다. 모든 그림을 영원히 붙잡으면 오히려 메모리가 늘므로
#       추정 크기 합이 BUDGET_BYTES를 넘으면 가장 오래 안 쓴 것부터 놓는다 (LRU, 화면에 떠 있는 것은 노드가 계속 붙잡고 있다)
class_name TextureCache
extends RefCounted

const MAX_SOURCE_SIZE: int = 2048
const RESIZE_TO: int = 1280
## 캐시가 붙잡아 둘 그림의 추정 메모리 상한 (RGBA8 + 밉맵 기준).
const BUDGET_BYTES: int = 128 * 1024 * 1024

static var _texture_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}
## 경로 -> 추정 바이트. 순서가 곧 최근 사용 순서다 (맨 뒤가 가장 최근).
static var _sizes: Dictionary = {}
static var _total_bytes: int = 0


## 경로의 텍스처를 캐시에서 꺼낸다 (없으면 한 번 불러와 넣는다). 파일이 없으면 null.
static func fetch(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		_touch(path)
		return _texture_cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = _shrink_if_huge(load(path) as Texture2D)
	_texture_cache[path] = texture  # 없는 파일도 기억해 다시 디스크를 뒤지지 않는다
	_remember(path, texture_bytes(texture))
	return texture


## 한순간만 쓰는 큰 그림(처치 컷인 일러스트 등): 캐시에 붙잡지 않는다. 연출 노드가 지워져 참조가 0이 되면 메모리(VRAM)에서 바로 내려간다.
## 이미 캐시에 있는 그림이면 그것을 쓴다.
static func fetch_transient(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path):
		return null
	return _shrink_if_huge(load(path) as Texture2D)


## root 아래의 그림 중 keep_dirs(폴더 경로) 어디에도 들지 않는 것을 캐시에서 놓는다. 놓은 개수를 돌려준다.
## 판이 시작할 때 이번 판에 앉지 않은 사도의 그림·애니메이션을 내린다 (화면에 떠 있는 것은 노드가 계속 붙잡는다).
static func forget_under(root: String, keep_dirs: Array) -> int:
	var dropped: int = 0
	for path: String in _sizes.keys():
		if not path.begins_with(root + "/"):
			continue
		if keep_dirs.any(func(dir: String) -> bool: return path.begins_with(dir + "/")):
			continue
		_total_bytes -= int(_sizes[path])
		_sizes.erase(path)
		_texture_cache.erase(path)
		_frames_cache.erase(path)
		dropped += 1
	return dropped


## 스프라이트 시트(SpriteFrames) 캐시.
static func fetch_frames(path: String) -> SpriteFrames:
	if path.is_empty():
		return null
	if _frames_cache.has(path):
		_touch(path)
		return _frames_cache[path]
	var frames: SpriteFrames = load(path) as SpriteFrames if ResourceLoader.exists(path) else null
	_frames_cache[path] = frames
	_remember(path, frames_bytes(frames))
	return frames


static func has_path(path: String) -> bool:
	return fetch(path) != null


static func size() -> int:
	return _texture_cache.size() + _frames_cache.size()


static func total_bytes() -> int:
	return _total_bytes


static func clear() -> void:
	_texture_cache.clear()
	_frames_cache.clear()
	_sizes.clear()
	_total_bytes = 0


## 그림 한 장의 추정 메모리 (RGBA8, 밉맵이 있으면 1/3 더).
static func texture_bytes(texture: Texture2D) -> int:
	if texture == null:
		return 0
	var bytes: int = texture.get_width() * texture.get_height() * 4
	return bytes * 4 / 3


static func frames_bytes(frames: SpriteFrames) -> int:
	if frames == null:
		return 0
	var seen: Dictionary = {}
	var bytes: int = 0
	for animation: StringName in frames.get_animation_names():
		for index: int in frames.get_frame_count(animation):
			var texture: Texture2D = frames.get_frame_texture(animation, index)
			var key: Variant = (texture as AtlasTexture).atlas if texture is AtlasTexture else texture
			if key == null or seen.has(key):
				continue
			seen[key] = true
			bytes += texture_bytes(key as Texture2D)
	return bytes


static func _touch(path: String) -> void:
	var bytes: int = int(_sizes.get(path, 0))
	_sizes.erase(path)
	_sizes[path] = bytes


static func _remember(path: String, bytes: int) -> void:
	_sizes[path] = bytes
	_total_bytes += bytes
	# 예산을 넘으면 가장 오래 안 쓴 것부터 놓는다 (방금 넣은 것은 남긴다)
	while _total_bytes > BUDGET_BYTES and _sizes.size() > 1:
		var oldest: String = _sizes.keys()[0]
		_total_bytes -= int(_sizes[oldest])
		_sizes.erase(oldest)
		_texture_cache.erase(oldest)
		_frames_cache.erase(oldest)


## 2048px를 넘는 원본은 비율을 지켜 1280px 이하로 한 번 줄인 ImageTexture로 바꾼다.
static func _shrink_if_huge(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var longest: int = maxi(texture.get_width(), texture.get_height())
	if longest <= MAX_SOURCE_SIZE:
		return texture
	var image: Image = texture.get_image()
	if image == null:
		return texture
	if image.is_compressed() and image.decompress() != OK:
		return texture
	var ratio: float = float(RESIZE_TO) / float(longest)
	image.resize(maxi(int(image.get_width() * ratio), 1), maxi(int(image.get_height() * ratio), 1), Image.INTERPOLATE_LANCZOS)
	if image.has_mipmaps():
		image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
