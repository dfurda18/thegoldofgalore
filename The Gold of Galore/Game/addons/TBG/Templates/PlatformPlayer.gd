@tool

## this is a custom asset with very basic interactivity

extends CharacterBody2D

## Get the gravity from the project settings (pixels/s/s)

@export var default_speed: float = 100.0
@export var jump_height: float = 200.0
@export var minimum_floor_time: float = 0.1
@export var tbg_scene_path: NodePath

@onready var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var tbg_scene: TBG.MotionCharacter = get_node(tbg_scene_path)


var _camera :
	get:
		if !is_instance_valid(_camera):
			_camera = TBG.find_node(self, Camera2D)
		return _camera


## in 2d modes we are current player when a camera2d is attached and set to current
var is_current :
	get:
		return _camera && _camera.is_current()


var control_sprint :
	get:
		return Input.is_key_pressed(KEY_SHIFT)


var control_action :
	get:
		if is_current:
			return Input.is_action_just_pressed("ui_accept")
		return false


var control_direction :
	get:
		if is_current:
			return Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up"))
			
		return Vector2.ZERO


# while this value > 0 we are considered "on floor"
var _remaining_floor_time = minimum_floor_time


## The main reason to use notifications here instead of virtual methods
## is that notifications will not be overridden
## if another script extends this one and implements [code]_physics_process(delta)[code]
## the NOTIFICATION_PHYSICS_PROCESS will still be received here
func _notification(what):
	match what:
		NOTIFICATION_READY:
			tbg_scene.mode = "Idle"
			set_physics_process(true)
			pass
		NOTIFICATION_PHYSICS_PROCESS:
			if Engine.is_editor_hint(): # don't do anything in the editor by default
				return
			
			var delta = (1.0 / Engine.physics_ticks_per_second)
			
			if is_on_floor():
				_remaining_floor_time = minimum_floor_time
			else:
				_remaining_floor_time -= delta
				
			var free_fall = _remaining_floor_time < 0
			
			var dir = control_direction
			var _scale = transform.x.length()
			
				# adjust character facing direction	
			if dir.x:
				var _facing = TBG.Direction.None
				
				if dir.x < 0:
					_facing = _facing | TBG.Direction.Left as TBG.Direction
				elif dir.x > 0:
					_facing = _facing | TBG.Direction.Right as TBG.Direction
					
				tbg_scene.facing = _facing
			
			# now pick motion mode
			if !free_fall:
				if control_action:
					tbg_scene.mode = "Action"
				elif dir.y > 0:
					tbg_scene.mode = "Jump"
				elif dir.y < 0:
					tbg_scene.mode = "Crawl" if dir.x else "Crouch"
				elif dir.x:
					tbg_scene.mode = "Run" if control_sprint else "Walk"
				else:
					tbg_scene.mode = "Idle"
			
			if free_fall:
				velocity += up_direction * -(gravity * delta) 
				
				# velocity.x = lerp(velocity.x, dir.x * speed * _scale * 0.5, 0.05)
			else:
				if dir:
					if tbg_scene.mode == "Jump":
						_remaining_floor_time = 0
						velocity.y = dir.y * -sqrt(2 * gravity * jump_height * _scale * (1.5 if control_sprint else 1))						
					
					elif tbg_scene.current_motion && !tbg_scene.current_motion.travel.is_zero_approx():
						velocity = tbg_scene.current_motion.travel * tbg_scene.speed_scale * _scale
					
					else:
						velocity = dir * Vector2(default_speed * tbg_scene.speed_scale * _scale, -default_speed * tbg_scene.speed_scale * _scale)
					
				else:
					velocity = velocity * 0.75
					if velocity.length() < default_speed * _scale * 0.1:
						velocity = Vector2.ZERO
			
			move_and_slide()
