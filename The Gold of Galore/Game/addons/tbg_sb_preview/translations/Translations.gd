@tool
extends Node
class_name SBPreviewTranslations

const TRANSLATION_PATH = "res://addons/tbg_sb_preview/translations/Plugin Translations - SB Preview.csv"

var translations = {}
var locale = "en"

# Called when the node enters the scene tree for the first time.
func setup():
	var trans_file = FileAccess.open(TRANSLATION_PATH, FileAccess.READ)
	var headers = trans_file.get_csv_line()
	var skipped_first = false
	
	for header in headers:
		if not skipped_first:
			skipped_first = true
			continue
		
		var translation = Translation.new()
		translation.locale = header
		translations[header] = translation
	
	while not trans_file.eof_reached():
		var csv_line = trans_file.get_csv_line()
		var msg_key = ""
		
		for i in csv_line.size():
			if i == 0:
				msg_key = csv_line[i]
			else:
				translations.values()[i-1].add_message(msg_key, csv_line[i])

func get_translation(key:String) -> String:
	if translations.is_empty():
		setup()
	
	locale = SB.plugin.editor.get_editor_settings().get_setting("interface/editor/editor_language")
	
	#Standardize to use "-" to separate language region in the code, godot uses "_" otherwise
	locale = locale.replace("_", "-")
	
	#If using for example pt-BR and no explicit translation for that locale code then check only for pt code
	if locale.contains("-") and not translations.has(locale):
		locale = locale.split("-")[0]
	
	if not translations.has(locale):
		var trans_msg = translations["en"].get_message(key)
		if not trans_msg:
			return key
		else:
			return trans_msg
			
	var trans_msg:String = translations[locale].get_message(key)
	
	if not trans_msg:
		return key
	
	return trans_msg
