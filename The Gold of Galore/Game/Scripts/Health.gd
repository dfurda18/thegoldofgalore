extends Resource
class_name Health

@export var MAX_HEALTH:int: set = set_MAX_HEALTH, get = get_MAX_HEALTH
var currentHealth:int: set = setHealth, get = getHealth

signal Died
signal HP_changed
signal Take_Damage
signal HP_reset

func get_MAX_HEALTH()->int:
	return MAX_HEALTH
	
func set_MAX_HEALTH(value:int):
	MAX_HEALTH = value
	currentHealth = MAX_HEALTH

func take_damage():
	currentHealth -= 1
	emit_signal("Take_Damage")

func setHealth(value:int):
	currentHealth = value
	emit_signal("HP_changed")
	if currentHealth == 0:
		emit_signal("Died")
		
func getHealth() -> int:
	return currentHealth

func Reset():
	currentHealth = MAX_HEALTH
	emit_signal("HP_reset")
