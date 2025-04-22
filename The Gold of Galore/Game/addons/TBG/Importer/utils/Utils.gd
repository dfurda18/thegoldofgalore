extends Node
class_name Utils

static func read_zip_file(zip_path: String):
	var result = {}
	
	var zip_reader := ZIPReader.new()
	
	if zip_reader.open(zip_path) != OK:
		print("Failed to open ZIP file: %s" % zip_path)
		return

	for file_path in zip_reader.get_files():
		var file_content := zip_reader.read_file(file_path)
		var text_content := file_content.get_string_from_utf16() 
		
		result[file_path] = file_content
	
	zip_reader.close()
	return result

static func remove_duplicates_from_arr(arr: Array) -> Array:
	var unique_array = []
	for item in arr:
		if item not in unique_array:
			unique_array.append(item)
	return unique_array
