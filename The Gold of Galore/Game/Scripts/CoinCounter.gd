extends Resource
class_name CoinCounter

# Track how many are in the level
var coin_count:int

@export var coin_max:int

var current_coins:int = 0

signal Added_coins
signal Reset_counters

func add_coin(amount:int):
	current_coins += amount
	emit_signal("Added_coins")

func Reset():
	current_coins = 0
	coin_count = 0
	emit_signal("Reset_counters")
