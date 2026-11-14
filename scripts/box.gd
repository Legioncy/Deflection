class_name Box
extends RefCounted

## What a box does to a ball that hits it.
## BOUNCE: ball reverses. STOP: ball drops and goes back to your inventory. VANISH: ball is lost.
enum Response { BOUNCE, STOP, VANISH }

const KINDS := {
	"rubber": {"color": Color(0.90, 0.55, 0.20), "response": Response.BOUNCE},
	"sticky": {"color": Color(0.40, 0.75, 0.30), "response": Response.STOP},
	"void":   {"color": Color(0.35, 0.20, 0.50), "response": Response.VANISH},
}

## Box-pushed-into-box effects, keyed "pusher>target". Missing pairs are "blocked".
## Effects understood by Sim.push_box:
##   "blocked"        nothing moves
##   "chain"          the target is pushed along first (if it can move)
##   "destroy_target" the target is removed and the pusher moves in
##   "destroy_both"   both are removed
const COMBOS := {
	"rubber>rubber": "chain",
	"sticky>rubber": "chain",
	"void>rubber": "destroy_target",
	"void>sticky": "destroy_target",
	"void>void": "destroy_both",
}

var kind: String = "rubber"
var pos := Vector2i.ZERO
## Direction the box is sliding in (non-zero only while it is on ice).
var slide := Vector2i.ZERO


func clone() -> Box:
	var b := Box.new()
	b.kind = kind
	b.pos = pos
	b.slide = slide
	return b
