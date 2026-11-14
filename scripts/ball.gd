class_name Ball
extends RefCounted
## A ball in flight. Add new ball types by adding an entry to KINDS
## (and reading the new fields in Sim where they matter).

const KINDS := {
	"normal":  {"color": Color(0.95, 0.95, 0.95), "damage": 0},
	"painful": {"color": Color(0.95, 0.25, 0.25), "damage": 1},
}

var kind: String = "normal"
var pos := Vector2i.ZERO
var dir := Vector2i.RIGHT
## 1 normally. A piston sets it to 2: the ball then moves boxes and the player 2 tiles.
var power := 1
## Ticks left before the ball is lost. Stops endless bounce loops.
var lifetime := 80
## False for the twin created by a splitter, so splitting can't duplicate your inventory.
var refund := true


func clone() -> Ball:
	var b := Ball.new()
	b.kind = kind
	b.pos = pos
	b.dir = dir
	b.power = power
	b.lifetime = lifetime
	b.refund = refund
	return b
