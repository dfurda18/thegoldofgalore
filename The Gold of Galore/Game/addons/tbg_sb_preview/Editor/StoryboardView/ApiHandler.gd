@tool
extends Node
class_name ApiHanlder

const API = "http://127.0.0.1"
const API_GET_DATA_FROM_GS = "gameStoryboard/exportJson"
const API_SAVE_GS = "gameStoryboard/saveAll"
const API_EXPORT_THUMBNAILS = "gameStoryboard/exportThumbnails"
const API_UPDATE_GS = "gameStoryboard/updateGameStoryboard"
const REQUEST_TIMEOUT = 5.0

var port = -1
var has_connection = true
var sync_required = false
var show_is_gsb_opened_msg_once = true

signal request_completed(result, request_type, is_queued_update)
signal request_failed(result, request_type, is_queued_update)
signal request_not_sent

func _ready():
	get_port()

func get_port():
	var port_file = FileAccess.open("../gsbport.cfg", FileAccess.READ)
	if not port_file:return
	port = int(port_file.get_as_text())
	port_file.close()

func get_thumbnails(export_type, id=null):
	var request_args = "?exportType="+export_type
	if id != null:
		request_args += "&id="+id
	create_request(SB.REQUEST.EXPORT_THUMBNAILS, API_EXPORT_THUMBNAILS + request_args)

func save_gs():
	create_request(SB.REQUEST.SAVE_GS, API_SAVE_GS)

func get_scene_data_from_gs(scene_id):
	var url_postfix = API_GET_DATA_FROM_GS + "?sceneId="+scene_id
	create_request(SB.REQUEST.GET_SCENE_DATA_FROM_GS, url_postfix)

func get_data_from_gs():
	create_request(SB.REQUEST.GET_DATA_FROM_GS, API_GET_DATA_FROM_GS)

func custom_request(request_type, url_postfix, args):
	create_request(request_type, url_postfix, args)

func update_gs(data, args={}, request_type=SB.REQUEST.UPDATE_GS):
	create_request(request_type, API_UPDATE_GS, args, HTTPClient.METHOD_POST, JSON.stringify(data))

func create_request(request_type, url_postfix, args={}, method=HTTPClient.METHOD_GET, body=""):
	get_port()
	
	if sync_required and not request_type == SB.REQUEST.SYNC_UPDATE_DATA and not request_type == SB.REQUEST.SYNC_ADD_DELETE_DATA:
		if SB.storyboard_view.loaded_gs_data_one_time:
			SB.show_constant_message("SYNC_FIRST")
			return
	
	if port == -1:
		SB.show_constant_message("IS_GSB_OPENED")
		return
	
	if not SB.storyboard_view.loaded_gs_data_one_time and not request_type == SB.REQUEST.GET_DATA_FROM_GS and not request_type == SB.REQUEST.SAVE_GS:
		SB.show_constant_message("FORCE_GS_LOAD")
		return
	
	var url = API + ":" + str(port) + "/" + url_postfix
	var http_request:HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(on_request_completed.bind(request_type, http_request, args))
	http_request.timeout = REQUEST_TIMEOUT
	http_request.request(url, PackedStringArray(), method, body)

func on_request_completed(result, response_code, headers, body, request_type, http_request, args):
	has_connection = response_code == 200
	
	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data["success"]:
			emit_signal("request_completed", data, request_type, args)
			show_is_gsb_opened_msg_once = true
		else:
			emit_signal("request_failed", data, request_type, args)
	else:
		emit_signal("request_not_sent")
		port = -1
		if show_is_gsb_opened_msg_once:
			SB.show_constant_message("IS_GSB_OPENED")
			show_is_gsb_opened_msg_once = false
	
	http_request.queue_free()
