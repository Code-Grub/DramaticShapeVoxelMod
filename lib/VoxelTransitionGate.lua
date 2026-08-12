-- Visual blackout for destination loads which cannot safely reveal a partly
-- generated voxel scene.  Seamless overworld connections deliberately do not
-- use it: only Continue/boot, a real warp (doors, stairs, caves), and Fly arm
-- the gate.

local V = ...

local Gate = {
  HOLD_SECONDS = 0.5,
}

local active = false
local map = nil
local targetId = nil
local ready = false
local elapsed = 0

function Gate.qualifies(opts, hadMap)
  if opts and opts.seamless then return false end
  local via = opts and opts.via
  return via == "boot" or via == "fly" or via == "warp"
         or (via == nil and hadMap)
end

local function voxelEnabled()
  local Voxel = V.require("VoxelState")
  local Voxel3D = V.require("Voxel3D")
  return Voxel.active() and Voxel3D.available()
end

function Gate.arm(destinationOrId)
  if not destinationOrId then return end
  map = type(destinationOrId) == "table" and destinationOrId or nil
  targetId = map and map.id or destinationOrId
  active = true
  ready = false
  elapsed = 0
end

-- startWarpTo arms before the engine's fade and before the destination Map
-- object exists. Bind that object at setMap without restarting the clock.
function Gate.bind(destination)
  if not destination then return end
  if active and targetId == destination.id then
    map = destination
    return
  end
  Gate.arm(destination)
end

function Gate.cancel(destination)
  if destination ~= nil and destination ~= map then return end
  active, map, targetId, ready, elapsed = false, nil, nil, false, 0
end

function Gate.observe(destination, isReady)
  if not active or destination ~= map then return end
  if isReady then
    ready = true
  else
    ready = false
  end
end

function Gate.update(dt, enabled, destination)
  if not active then return end
  if not enabled then
    Gate.cancel()
    return
  end
  elapsed = elapsed + math.max(0, dt or 0)
  if ready and elapsed >= Gate.HOLD_SECONDS then
    Gate.cancel()
  end
end

function Gate.blocking(destination)
  -- Once a qualifying transition begins, cover whichever world the engine is
  -- currently drawing: initially the departing map, then the bound destination.
  return active
end

function Gate.install()
  local OverworldState = require("src.world.OverworldController")
  if OverworldState.dramaticShapeVoxelTransitionGate then return end

  local startWarpTo = OverworldState.startWarpTo
  function OverworldState:startWarpTo(mapId, x, y, facing, onDone, opts)
    if voxelEnabled() and Gate.qualifies(opts, self.map ~= nil) then
      Gate.arm(mapId)
    end
    return startWarpTo(self, mapId, x, y, facing, onDone, opts)
  end

  local setMap = OverworldState.setMap
  function OverworldState:setMap(mapId, x, y, facing, opts)
    local hadMap = self.map ~= nil
    local result = setMap(self, mapId, x, y, facing, opts)
    if voxelEnabled() and Gate.qualifies(opts, hadMap) then Gate.bind(self.map) end
    return result
  end

  OverworldState.dramaticShapeVoxelTransitionGate = true
end

-- Test-only state reset; harmless to expose and useful to keep the module's
-- temporal contract deterministic in the headless SDK suite.
function Gate._reset()
  Gate.cancel()
end

return Gate
