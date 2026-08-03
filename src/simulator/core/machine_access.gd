extends RefCounted
## MachineAccess — pure state machine for the pendant control station. This
## overhead crane is operated from a fixed point on the factory floor (a
## pendant/remote control box), not from a cabin — there is nothing to climb.
## Walk into range, pick up the pendant (instant), operate, put it down
## (instant). No scene dependency: fed a player position each frame, unit
## tested in tests/module_tests.gd.

enum State { OUTSIDE, IN_ZONE, CONTROLLING }

var state: int = State.OUTSIDE


func reset() -> void:
	state = State.OUTSIDE


## player_pos: world position of the player's feet. While CONTROLLING, the
## player is standing still holding the pendant, so we skip the distance
## re-check (try_exit() is the only way out of that state).
func update(_delta: float, player_pos: Vector3, access_point: Vector3,
		access_radius: float) -> void:
	if state == State.CONTROLLING:
		return
	var flat_dist := Vector2(player_pos.x - access_point.x,
		player_pos.z - access_point.z).length()
	state = State.IN_ZONE if flat_dist <= access_radius else State.OUTSIDE


## Picking up the pendant is instantaneous — it's a handheld box, not a climb.
func try_interact() -> bool:
	if state == State.IN_ZONE:
		state = State.CONTROLLING
		return true
	return false


## Putting the pendant down is instantaneous too. Falls back to OUTSIDE; the
## next update() call re-derives IN_ZONE if the player is still standing there.
func try_exit() -> bool:
	if state == State.CONTROLLING:
		state = State.OUTSIDE
		return true
	return false


func is_controlling() -> bool:
	return state == State.CONTROLLING


func state_name() -> String:
	match state:
		State.OUTSIDE: return "outside"
		State.IN_ZONE: return "in_zone"
		State.CONTROLLING: return "controlling"
		_: return "?"
