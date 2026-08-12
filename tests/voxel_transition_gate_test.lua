-- Focused temporal contract for the visual voxel destination blackout.

package.loaded["src.core.Game"] = {
  input = { reset = function() error("visual gate must not reset input") end },
}

local file = os.getenv("DS_TRANSITION_GATE")
  or "lib/VoxelTransitionGate.lua"
local chunk = assert(loadfile(file))
local Gate = chunk({ require = function() error("not needed by pure test") end })
local destination = {}

assert(Gate.qualifies({ via = "boot" }, false))
assert(Gate.qualifies({ via = "fly" }, nil))
assert(Gate.qualifies(nil, "fly"))
assert(Gate.qualifies(nil, "teleport"))
assert(not Gate.qualifies({ via = "warp" }, nil))
assert(not Gate.qualifies(nil, nil))
assert(not Gate.qualifies({ via = "connection", seamless = true }, nil))

Gate.arm("DESTINATION")
assert(Gate.blocking(nil))
Gate.update(0.49, true, nil)
assert(Gate.blocking(nil), "transition revealed before half a second")
destination.id = "DESTINATION"
Gate.bind(destination)
Gate.observe(destination, true)
Gate.update(0.01, true, destination)
assert(not Gate.blocking(destination), "ready world remained locked after half a second")

Gate.arm("SLOW_DESTINATION")
Gate.update(2, true, nil)
destination.id = "SLOW_DESTINATION"
Gate.bind(destination)
assert(Gate.blocking(destination), "unfinished voxels revealed after timer elapsed")
Gate.observe(destination, true)
Gate.update(0, true, destination)
assert(not Gate.blocking(destination), "late voxels did not reveal immediately")

Gate._reset()
Gate.bind(destination)
assert(not Gate.blocking(destination), "ordinary setMap must not arm the gate")

Gate.arm("BROKEN_DESTINATION")
Gate.update(Gate.MAX_SECONDS, true, nil)
assert(not Gate.blocking(nil), "failed destination trapped the player forever")

print("voxel transition gate: ok")
