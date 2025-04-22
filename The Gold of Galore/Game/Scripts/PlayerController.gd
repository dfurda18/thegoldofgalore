extends CharacterBody2D

@export_category("Movement Variables")
## Speed of movement side to side
@export var SPEED = 300.0
## More negative means higher jump
@export var JUMP_VELOCITY = -1200.0
## Multiplier for gravity
@export var WEIGTH = 3
## Movement left and right while in air
@export var IN_AIR_MOVEMENT_SPEED = 500.0
## How fast the player will change direction while in air
@export var IN_AIR_DIRECTION_CHANGE_SPEED = 10.0

@export_category("Resources")
@export var HP:Health
@export var Count:CoinCounter

@export_category("Camera")
@export var Camera:Camera2D

@export_category("Animations")
@export var ANIM:MotionCharacter

#@onready var footsteps_audio = $Audio/FootstepsAudio
#@onready var jump_audio = $Audio/JumpAudio
#@onready var pickup_audio = $Audio/PickupAudio
#@onready var attack_audio = $Audio/AttackAudio
#@onready var death_audio = $Audio/DeathAudio
#@onready var hit_audio = $Audio/HitAudio
#@onready var take_hit_audio = $Audio/TakeHitAudio

#var enemy_in_range:bool = false
var facing_right:bool = true
#Used to prevent other actions during attack anim
var is_attacking:bool = false
var player_dead:bool = false
var can_be_hit:bool = true
var in_water:bool = false

signal playerDied

func _ready():
	ANIM.facing = TBG.Direction.Right
	HP.connect("Died", player_died)

func _physics_process(delta):
	if player_dead:
		return
	move_and_slide()

func toggleCameraFollow():
	Camera.setLockPosition()
	Camera.toggleCameraFollow()

func check_facing(d:float):
	# Face the right direction, flipping
	if d > 0 and facing_right == false:
		facing_right = true
		ANIM.facing = TBG.Direction.Right
		$Hurtbox.position.x = 144
	elif d < 0 and facing_right ==true:
		facing_right = false
		ANIM.facing = TBG.Direction.Left
		$Hurtbox.position.x = -166

func attack_hit_check():
	var overlapping_objects = $Hurtbox.get_overlapping_areas()
	for obj in overlapping_objects:
		if obj.is_in_group("Hitbox"):
			var e = obj.get_parent()
			if e.is_in_group("Enemy"):
				#hit_audio.play()
				e.take_hit()
				Camera.shake(0.2, 1)

func player_take_hit():
	if can_be_hit:
		#take_hit_audio.play()
		can_be_hit = false
		Camera.shake(0.2, 1)
		$StateMachine.state_transition($StateMachine.current_state, "TakeHit")

func player_died():
	player_dead = true
	#death_audio.play()
	emit_signal("playerDied")
	
func _on_hitbox_area_entered(area):
	if area.is_in_group("Potion"):
		area.queue_free()
		HP.Reset()
		#pickup_audio.pitch_scale = 1.0
		#pickup_audio.play()
	elif area.is_in_group("Gem1"):
		area.queue_free()
		Count.Gem1_count += 1
		Count.add_bits(10)
		#pickup_audio.pitch_scale = 1.1
		#pickup_audio.play()
	elif area.is_in_group("Gem2"):
		Count.Gem2_count += 1
		area.queue_free()
		Count.add_bits(20)
		#pickup_audio.pitch_scale = 1.2
		#pickup_audio.play()
	elif area.is_in_group("Gem3"):
		Count.Gem3_count += 1
		area.queue_free()
		Count.add_bits(50)
		#pickup_audio.pitch_scale = 1.3
		#pickup_audio.play()
