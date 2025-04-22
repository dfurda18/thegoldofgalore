@tool
extends Control
class_name Toast

@export var time_visible = 3.0
@export var success_color:Color
@export var error_color:Color
@export var info_color:Color = Color.WHITE

var MessageScene = load("res://addons/tbg_sb_preview/Editor/UI_Components/Toast/ToastMessage.tscn")
var start_position := Vector2.ZERO
var timer:Timer = Timer.new()
var offset = 10
var messages_active = 0
var max_messages = 2
var messages = []

func show_toast(text, type=SB.TOAST_TYPE.SUCCESS):
	show()
	
	var message = MessageScene.instantiate()
	add_child(message)
	message.connect("kill", on_message_kill.bind(message))
	messages.append(message)
	
	var color = success_color
	match type:
		SB.TOAST_TYPE.ERROR:
			color = error_color
		SB.TOAST_TYPE.INFO:
			color = info_color
	
	var offset = (messages_active * message.custom_minimum_size.y) + 5 * messages_active
	messages_active += 1
	
	if messages_active > max_messages:
		messages[0].emit_signal("kill")
		offset_other_messages(message)
	
	message.set_color(color)
	message.set_message_text(SB.get_tr(text))
	var tween:Tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUINT)
	tween.set_parallel(true)
	tween.tween_property(message, "position:y", size.y - (50 * SB.get_screen_scale()) - offset, 1.0).from(size.y + 100)
	tween.tween_property(message, "modulate:a", 1.0, 1.0).from(0.0)

func on_message_kill(message):
	var tween:Tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUINT)
	tween.set_parallel(true)
	tween.tween_callback(offset_other_messages.bind(message)).set_delay(1.0)
	tween.tween_callback(message.queue_free).set_delay(1.0)
	tween.tween_property(message, "position:y", size.y + 100, 1.0)
	tween.tween_property(message, "modulate:a", 0.0, 1.0).from(1.0)
	messages_active -= 1
	messages.erase(message)

func offset_other_messages(message):
	var offset = false
	for msg in get_children():
		if msg == message:
			offset = true
			continue
		if offset:
			msg.position.y += msg.size.y + 5 
