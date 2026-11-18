extends Node3D

# =====================================================================
# FACKEL
# Lässt das Licht unregelmässig flackern, wie bei echtem Feuer.
# =====================================================================

@export var grund_helligkeit = 1.5
@export var flacker_staerke = 0.4
@export var mit_schatten = true           # Schatten kosten Leistung

@onready var licht = $Licht

var zeit = 0.0


func _ready():
	# Jede Fackel startet anders, damit nicht alle gleich flackern.
	zeit = randf_range(0.0, 100.0)
	licht.shadow_enabled = mit_schatten


func _process(delta):
	zeit = zeit + delta
	var flackern = sin(zeit * 9.0) * 0.5 + sin(zeit * 23.0) * 0.3 + sin(zeit * 41.0) * 0.2
	licht.light_energy = grund_helligkeit + flackern * flacker_staerke
