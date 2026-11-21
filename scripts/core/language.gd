class_name Language
extends RefCounted
## Game language. Vietnamese text is the source and the translation key; English comes from
## `data/lang/en.po`, loaded only when English is chosen, so Vietnamese stays the default
## whatever the OS locale is. Labels and buttons translate their text automatically; code
## that builds a sentence from parts runs each part through `t()`.

const CODES := ["vi", "en"]
const NAMES := ["Tiếng Việt", "English"]
const ENGLISH := "res://data/lang/en.po"

static var code := "vi"
static var _english: Translation


## Switches the whole game; unknown codes fall back to Vietnamese.
static func apply(new_code: String) -> void:
	code = new_code if new_code in CODES else "vi"
	if code == "en" and _english == null:
		_english = load(ENGLISH) as Translation
		if _english != null:
			TranslationServer.add_translation(_english)
	TranslationServer.set_locale(code)


static func index() -> int:
	return CODES.find(code)


## The current language's text for a Vietnamese source string.
static func t(text: String) -> String:
	if code == "vi":
		return text
	return String(TranslationServer.translate(text))
