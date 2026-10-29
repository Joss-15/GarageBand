## song_library.gd
## Lectura de las canciones locales de res://songs/.
## Cada canción vive en su propia subcarpeta:
##   songs/<carpeta>/<nombre>.wav            (audio)
##   songs/<carpeta>/<nombre>.json           (mapa de notas base)
##   songs/<carpeta>/<nombre>_<instrumento>.json   (opcional, un mapa por instrumento)
##   songs/<carpeta>/info.json               (opcional: {"title": "...", "artist": "..."})
##   songs/<carpeta>/cover.png|jpg           (opcional: portada)
extends RefCounted

const RB = preload("res://scripts/core/rb_theme.gd")

const SONGS_PATH := "res://songs/"
const COVER_NAMES := ["cover.png", "cover.jpg", "cover.jpeg", "cover.webp"]

static var _cache: Array = []
static var _loaded: bool = false
static var _diff_cache: Dictionary = {}


## Lista de canciones ordenada alfabéticamente por título.
static func scan(force: bool = false) -> Array:
	if _loaded and not force:
		return _cache
	var result: Array = []
	var dir := DirAccess.open(SONGS_PATH)
	if dir != null:
		dir.list_dir_begin()
		var folder: String = dir.get_next()
		while folder != "":
			if dir.current_is_dir() and not folder.begins_with("."):
				var song: Dictionary = _read_folder(SONGS_PATH + folder + "/")
				if not song.is_empty():
					result.append(song)
			folder = dir.get_next()
		dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["sort_key"]) < str(b["sort_key"]))
	_cache = result
	_loaded = true
	_diff_cache.clear()
	return result


static func find_by_name(song_name: String) -> Dictionary:
	for s in scan():
		var song: Dictionary = s
		if str(song["name"]) == song_name:
			return song
	return {}


static func _read_folder(folder_path: String) -> Dictionary:
	var d := DirAccess.open(folder_path)
	if d == null:
		return {}
	var wav: String = ""
	d.list_dir_begin()
	var f: String = d.get_next()
	while f != "":
		if not d.current_is_dir():
			var clean: String = f.trim_suffix(".import").trim_suffix(".remap")
			if clean.get_extension().to_lower() == "wav" and wav == "":
				wav = folder_path + clean
		f = d.get_next()
	d.list_dir_end()
	if wav == "":
		return {}

	var stem: String = wav.get_file().get_basename()
	var meta: Dictionary = {}
	var info_path: String = folder_path + "info.json"
	if FileAccess.file_exists(info_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(info_path))
		if parsed is Dictionary:
			meta = parsed as Dictionary
	var title: String = str(meta.get("title", ""))
	var artist: String = str(meta.get("artist", ""))
	if title == "":
		var guess: PackedStringArray = _guess_title_artist(stem)
		title = guess[0]
		if artist == "":
			artist = guess[1]

	var cover: String = ""
	for cn in COVER_NAMES:
		var cp: String = folder_path + str(cn)
		if ResourceLoader.exists(cp):
			cover = cp
			break

	var letter: String = title.substr(0, 1).to_upper()
	if letter.length() == 0 or letter < "A" or letter > "Z":
		letter = "#"

	return {
		"name": stem,
		"title": title,
		"artist": artist,
		"wav": wav,
		"folder": folder_path,
		"cover": cover,
		"letter": letter,
		"sort_key": title.to_lower(),
	}


static func _guess_title_artist(stem: String) -> PackedStringArray:
	var s: String = stem.replace("_", " ")
	var artist: String = ""
	var title: String = s
	var idx: int = s.find("-")
	if idx > 0 and idx < s.length() - 1:
		artist = s.substr(0, idx).strip_edges()
		title = s.substr(idx + 1).strip_edges()
	return PackedStringArray([_split_camel(title), _split_camel(artist)])


## "ImNotOkay" -> "Im Not Okay"
static func _split_camel(s: String) -> String:
	if s == "" or s.contains(" "):
		return s
	var re := RegEx.new()
	re.compile("([a-z])([A-Z])")
	return re.sub(s, "$1 $2", true)


# ── Mapas de notas ───────────────────────────────────────────────────────────

static func beatmap_path(song: Dictionary, instrument: String) -> String:
	var base: String = str(song.get("wav", "")).get_basename()
	var inst_path: String = base + "_" + instrument + ".json"
	if FileAccess.file_exists(inst_path):
		return inst_path
	return base + ".json"


static func load_beatmap(song: Dictionary, instrument: String) -> Dictionary:
	var path: String = beatmap_path(song, instrument)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


## Dificultad 0-5 estimada por densidad de notas (0 = sin mapa).
static func difficulty(song: Dictionary, instrument: String) -> int:
	var key: String = str(song.get("name", "")) + "|" + instrument
	if _diff_cache.has(key):
		return int(_diff_cache[key])
	var level: int = 0
	var bm: Dictionary = load_beatmap(song, instrument)
	if not bm.is_empty():
		var notes: Array = bm.get("notes", [])
		var duration: float = float(bm.get("duration", 0.0))
		if duration > 1.0 and not notes.is_empty():
			var nps: float = float(notes.size()) / duration
			if nps < 0.6:
				level = 1
			elif nps < 1.2:
				level = 2
			elif nps < 2.0:
				level = 3
			elif nps < 3.0:
				level = 4
			else:
				level = 5
	_diff_cache[key] = level
	return level


# ── Récords (SQLite local) ───────────────────────────────────────────────────

## Mejor marcador guardado de la canción ({} si no hay o no hay base de datos).
static func best_record(song_name: String) -> Dictionary:
	if Database == null or Database.db == null:
		return {}
	var rows: Array = Database.get_top10(song_name)
	if rows.is_empty():
		return {}
	return rows[0] as Dictionary


static func best_stars(song_name: String) -> int:
	var rec: Dictionary = best_record(song_name)
	if rec.is_empty():
		return 0
	return RB.stars_for(float(rec.get("accuracy", 0.0)))


static func total_stars() -> int:
	var total: int = 0
	for s in scan():
		var song: Dictionary = s
		total += best_stars(str(song["name"]))
	return total
