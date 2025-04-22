extends Camera2D

@export_category("Follow Character")
## Player controller too follow around
@export var player:CharacterBody2D

@export var Y_Offset:int

@export_category("Camera Smoothing")
## Smoothing on or off
@export var smoothing_enabled:bool = true
## Amount of smoothing pixels/sec
@export_range(1,10) var smoothing_distance:int  = 8

# CAMERA SHAKE
var shake_amount:float
var default_offset:Vector2

@onready var timer:Timer = $Timer

# CAMERA FOLLOW
var camera_follow:bool = true
var lock_position:Vector2 = Vector2(0,0)
var camera_position : Vector2

func _ready():
	$Color.show()
	set_process(true)
	randomize()

func _process(_delta):
	offset = Vector2(randf_range(-1,1) * shake_amount,
			 randf_range(-1,1) * shake_amount)

func _physics_process(_delta):
	if player != null:
		if camera_follow:
			if smoothing_enabled:
				var weight = float(11 - smoothing_distance) / 100
				camera_position.x = lerp(global_position.x,player.global_position.x,weight)
				camera_position.y = lerp(global_position.y,player.global_position.y - Y_Offset,weight)
			else:
				camera_position.x = player.global_position.x
				camera_position.y = player.global_position.y - Y_Offset
		else:				
			camera_position = lock_position
		global_position = camera_position.floor()

# Set how long the camera shakes, how strong the shake is
func shake(time:float, amount:float):
	timer.wait_time = time
	shake_amount = amount
	set_process(true)
	timer.start()

func toggleCameraFollow():
	camera_follow = !camera_follow

func setLockPosition():
	lock_position = camera_position
		
func _on_timer_timeout():
	set_process(false)
	Tween.interpolate_value(self,"offset",1,1,Tween.TRANS_LINEAR,Tween.EASE_IN)
