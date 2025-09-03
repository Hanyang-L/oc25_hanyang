extends Node2D

#@onready var player: CharacterBody2D = $Player
#@onready var dragon: Node2D = $dragon


#func_process(_delta: float) -> void:
	
	#if player.global_position.x ‹ dragon.global_position.x:
		#dragon.scale.x=-1
	#else:
		#dragon.scale.x=1
