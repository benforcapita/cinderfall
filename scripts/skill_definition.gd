extends Resource
@export var id = ""
@export var title = ""
@export var cost = 0.0
@export var cooldown = 0.5
@export var windup = 0.1
@export var recovery = 0.1
@export var range = 3.0
@export var power = 1.0
@export_enum("self", "direction", "ground", "actor") var targeting = "direction"
@export var effects: Array[Dictionary] = []
