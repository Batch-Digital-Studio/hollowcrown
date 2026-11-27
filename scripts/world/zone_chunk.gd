class_name ZoneChunk
extends Node2D
## One 10x10-cell slice of the zone, so 2D lights are culled per chunk.

var zone: Zone
var r: Rect2i

func _draw() -> void:
	zone.draw_cells(self, r.position.x, r.position.y, r.end.x, r.end.y)
