extends Node2D

@export var PLAYER:CharacterBody2D
@export var PlayerHP:Health
@export var Count:CoinCounter

var curr_check:Vector2
var win:bool = false

signal GameOver
signal GameWon

func _ready():
	curr_check = $PlayerSpawn.global_position
	
	# Make sure HP values are set to Max
	#for e in $Enemies.get_children():
	#	e.HP.Reset()		
	PlayerHP.Reset()
	Count.Reset()
	
	#Connect checkpoints
	#for c in $Checkpoints.get_children():
	#	c.connect("CheckpointReached", on_checkpoint_checkpoint_reached) 
	#Connect damage zones
	#for d in $DamageZones.get_children():
	#	d.connect("respawn_player", on_damge_return_respawn_player) 

func on_checkpoint_checkpoint_reached(pos:Vector2):
	curr_check = pos

# prevent falling through too damage zones
var take_damge:bool = true
func on_damge_return_respawn_player():
	if take_damge:
		take_damge = false
		$AnimationPlayer.play("fade_out")
		PLAYER.HP.take_damage()
		PLAYER.death_audio.play()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "fade_out" and win:
		emit_signal("GameWon")
	elif anim_name == "fade_out" and !PLAYER.player_dead:
		PLAYER.global_position = curr_check
		$AnimationPlayer.play("fade_in")
		take_damge = true
	elif anim_name == "fade_out" and PLAYER.player_dead:
		emit_signal("GameOver")

func _on_player_controller_player_died():
	$AnimationPlayer.play("fade_out")

func _on_level_finish_area_entered(area):
	var overlapping_objects = $LevelFinish.get_overlapping_areas()
	for obj in overlapping_objects:
		if obj.is_in_group("Hitbox"):
			var p = obj.get_parent()
			if p.is_in_group("Player"):
				win = true
				$AnimationPlayer.play("fade_out")
