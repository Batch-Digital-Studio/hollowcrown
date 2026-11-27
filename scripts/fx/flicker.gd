extends PointLight2D
## Gentle torch flicker.
var _base := -1.0
var _t := 0.0
func _process(delta: float) -> void:
	if _base < 0.0:
		_base = energy
		_t = randf() * 10.0
	_t += delta
	energy = _base * (0.88 + 0.08 * sin(_t * 7.0) + 0.05 * sin(_t * 17.3))
