-- Focused standalone contract tests for the Voxel Companion API v1 host.

local checks = 0

local function check(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 0) end
end

local function equal(actual, expected, message)
  checks = checks + 1
  if actual ~= expected then
    error(("FAIL: %s (expected %s, got %s)")
      :format(message, tostring(expected), tostring(actual)), 0)
  end
end

local function contains(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) ~= nil, message)
end

local API = assert(loadfile("lib/VoxelCompanionAPI.lua"))()
equal(API.VERSION, 1, "vendored dispatcher reports API v1")

local graphicsState = { color = "host", depth = "host", blend = "host" }
local graphicsStack = {}
local pushCount, popCount = 0, 0
local sentinelUpdate = function() end

love = {
  update = sentinelUpdate,
  system = { getOS = function() return "Windows" end },
  image = {},
  graphics = {},
}

function love.image.newImageData()
  return { setPixel = function() end }
end

function love.graphics.newImage()
  return {
    setFilter = function() end,
    release = function(self) self.released = true end,
  }
end

function love.graphics.push(kind)
  equal(kind, "all", "render isolation uses the full graphics state")
  pushCount = pushCount + 1
  graphicsStack[#graphicsStack + 1] = {
    color = graphicsState.color,
    depth = graphicsState.depth,
    blend = graphicsState.blend,
  }
end

function love.graphics.pop()
  popCount = popCount + 1
  local previous = table.remove(graphicsStack)
  assert(previous, "unbalanced graphics pop")
  graphicsState = previous
end

function love.graphics.setColor(r, g, b, a)
  graphicsState.color = table.concat({ r, g, b, a }, ":")
end

function love.graphics.setDepthMode(mode, write)
  graphicsState.depth = tostring(mode) .. ":" .. tostring(write)
end

function love.graphics.setBlendMode(mode, alpha)
  graphicsState.blend = tostring(mode) .. ":" .. tostring(alpha)
end

local fakeVoxel3D = {
  FACE_CORNERS = {},
  FACE_SHADE = {},
  eye = { 0, 16, 32 },
  camera = {
    eye = { 8, 12, 24 },
    focus = { 8, 8, 8 },
    up = { 0, 1, 0 },
    fov = math.rad(65),
  },
  draws = 0,
  glassState = true,
  failNextDraw = false,
}

for direction = 1, 6 do
  fakeVoxel3D.FACE_CORNERS[direction] = {
    { 0, 0, 0 }, { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 },
  }
  fakeVoxel3D.FACE_SHADE[direction] = 1
end

function fakeVoxel3D.pushQuad(indices, offset)
  indices[#indices + 1] = offset
end

function fakeVoxel3D.newMesh(vertices, indices)
  return {
    vertices = vertices,
    indices = indices,
    release = function(self) self.released = true end,
  }
end

function fakeVoxel3D.glass(enabled)
  fakeVoxel3D.glassState = enabled
end

function fakeVoxel3D.draw()
  fakeVoxel3D.draws = fakeVoxel3D.draws + 1
  if fakeVoxel3D.failNextDraw then
    fakeVoxel3D.failNextDraw = false
    error("synthetic GPU draw failure", 0)
  end
end

local fakeMat4 = {
  mul = function(a, b) return { a, b } end,
  translate = function(x, y, z) return { "translate", x, y, z } end,
  scale = function(x, y, z) return { "scale", x, y, z } end,
  rotateY = function(value) return { "rotateY", value } end,
}

local fakeVoxelState = {
  isFirstPerson = function() return true end,
  isThirdPerson = function() return false end,
}

local fakeDayNight
fakeDayNight = {
  period = "DAY",
  isCanopy = function() return false end,
  tod = function() return fakeDayNight.period end,
  time = function() return 12.5 end,
}

local fakeShapes = {
  [0] = { class = "grass", h = 0 },
  [1] = { class = "wall", h = 8 },
  [2] = { class = "tree", h = 12 },
  [3] = { class = "water", h = 0 },
}

local fakeTileShape = {
  forMap = function() return fakeShapes end,
}

local fakeMapModule = {
  isOutdoor = function() return true end,
}

local fakeGame = { save = { version = "red" } }
package.loaded["src.world.Map"] = fakeMapModule
package.loaded["src.core.Game"] = fakeGame

local function cleanMod()
  local mod = { writes = 0, messages = {} }
  function mod:read() return "-- clean upstream host\n" end
  function mod:write()
    self.writes = self.writes + 1
    error("integrity scan must never write", 0)
  end
  mod.log = {
    error = function(_, format, value)
      mod.messages[#mod.messages + 1] = tostring(format):format(value)
    end,
  }
  return mod
end

local function namespace(mod)
  local modules = {
    VoxelCompanionAPI = API,
    Mat4 = fakeMat4,
    TileShape = fakeTileShape,
    VoxelState = fakeVoxelState,
    Voxel3D = fakeVoxel3D,
    DayNight = fakeDayNight,
  }
  return {
    mod = mod,
    require = function(name)
      local value = modules[name]
      assert(value, "unexpected module " .. tostring(name))
      return value
    end,
  }
end

local function worldState()
  local map = {
    id = "PALLET_TOWN",
    widthCells = 2,
    heightCells = 2,
    def = { width = 1, height = 1, tileset = "OVERWORLD" },
    tileset = { id = "OVERWORLD", image = "overworld-atlas" },
  }
  function map:cellTile(x, z) return z * 2 + x end
  function map:isWalkableCell(x, z) return not (x == 1 and z == 0) end
  function map:isWaterCell(x, z) return x == 1 and z == 1 end
  function map:isGrassCell(x, z) return x == 0 and z == 0 end
  function map:warpAtCell(x, z)
    return x == 0 and z == 1 and { target = "HOUSE" } or nil
  end
  function map:isWarpTileCell() return false end
  local player = { id = "player", px = 0, py = 0, cellX = 0, cellY = 0,
    facing = "down", gh = 0 }
  return {
    map = map,
    player = player,
    entities = {
      player,
      { id = "npc-1", kind = "npc", px = 16, py = 16,
        cellX = 1, cellY = 1, facing = "up" },
    },
    neighbors = {},
  }
end

local VoxelCompanion = assert(loadfile("lib/VoxelCompanion.lua"))(namespace(cleanMod()))
local mod = cleanMod()
local companion = VoxelCompanion.new({ mod = mod })
local provider = companion.provider

equal(provider.api, 1, "provider reports API v1")
equal(provider.host.id, "BATTLE_ART_VOXEL_FORK", "provider reports stable host id")
equal(provider.host.version, "1.9.7", "provider preserves upstream version")
for _, capability in ipairs({
  "world_snapshot", "camera_delta", "render_phases", "quality_tier",
  "integrity_status",
}) do
  equal(provider.capabilities[capability], 1, "provider advertises " .. capability)
end
for _, capability in ipairs({
  "terrain_patch", "shadow_pass", "battle_pass", "materials", "draw",
}) do
  equal(provider.capabilities[capability], nil,
    "provider does not over-advertise " .. capability)
end
equal(mod.writes, 0, "clean integrity scan is read-only")

local calls = {
  world = 0,
  update = 0,
  healthyRender = 0,
  faultyDispose = 0,
  invalidated = 0,
  disposed = 0,
}

local faulty, err = provider.register({
  api = 1,
  id = "test.draw-fault",
  priority = 0,
  requires = { "render_phases" },
  render = {
    background = function(context)
      love.graphics.setColor(0.1, 0.2, 0.3, 0.4)
      fakeVoxel3D.failNextDraw = true
      context.draw:mesh({
        geometry = { primitive = "box", width = 1, height = 1, depth = 1 },
        material = "test:fault",
      })
    end,
  },
  dispose = function() calls.faultyDispose = calls.faultyDispose + 1 end,
})
check(faulty, err or "fault extension registers")

local healthy
healthy, err = provider.register({
  api = 1,
  id = "test.kfp-like",
  priority = 10,
  requires = {
    "world_snapshot", "camera_delta", "render_phases", "quality_tier",
  },
  optional = {
    "terrain_patch", "shadow_pass", "battle_pass", "integrity_status",
  },
  attach = function(services)
    equal(services.quality:getTier(), "BALANCED", "quality facade returns canonical tier")
    local status = services.integrity:status()
    check(status.clean and not status.legacyMarkers, "integrity facade reports a clean host")
  end,
  worldChanged = function(snapshot)
    calls.world = calls.world + 1
    calls.worldId = snapshot.id
    calls.worldRevision = snapshot.revision
    calls.cellCount = #snapshot.cells
  end,
  update = function(frame)
    calls.update = calls.update + 1
    calls.quality = frame.qualityTier
    calls.dt = frame.dt
  end,
  modifyCamera = function(camera)
    equal(camera.mode, "first_person", "camera callback gets the canonical camera")
    return {
      positionDelta = { x = 1, y = 2, z = 3 },
      rotationDelta = { yaw = 0.1, pitch = -0.02, roll = 0 },
      fovDelta = 0.04,
    }
  end,
  render = {
    background = function(context)
      calls.healthyRender = calls.healthyRender + 1
      context.draw:mesh({
        geometry = { primitive = "box", x = 8, y = 4, z = 8,
          width = 2, height = 3, depth = 2 },
        material = "test:healthy",
      })
      context.draw:mesh({
        geometry = { primitive = "world_apron", width = 32, depth = 32,
          skirtDepth = 16 },
        material = "world:apron",
      })
    end,
  },
  invalidate = function(reason)
    calls.invalidated = calls.invalidated + 1
    calls.invalidateReason = reason
  end,
  dispose = function() calls.disposed = calls.disposed + 1 end,
})
check(healthy, err or "KFP-like extension registers")

local shadow
shadow, err = provider.register({
  api = 1,
  id = "test.flat-shadow",
  render = { shadow_casters = function() end },
})
equal(shadow, nil, "flat shadow callback is refused")
contains(err, "shadow_pass", "flat shadow refusal explains the missing capability")

local battle
battle, err = provider.register({
  api = 1,
  id = "test.flat-battle",
  render = { battle_opaque = function() end },
})
equal(battle, nil, "flat battle callback is refused")
contains(err, "battle_pass", "flat battle refusal explains the missing capability")

local nested
nested, err = provider.register({
  api = 1,
  id = "test.nested-shadow",
  phases = { shadow_casters = function() end },
})
equal(nested, nil, "legacy nested shadow callback is refused")
contains(err, "shadow_pass", "nested shadow refusal explains the missing capability")

check(companion:start(), "host dispatcher starts")
local state = worldState()
local updateReport = companion:update(0.016, state)
check(updateReport and updateReport.succeeded >= 1, "canonical update dispatch succeeds")
equal(calls.world, 1, "initial world identity dispatches one snapshot")
equal(calls.worldId, "PALLET_TOWN", "worldChanged receives the direct snapshot")
equal(calls.cellCount, 4, "world snapshot contains the real map cells")
equal(calls.quality, "BALANCED", "update receives the direct canonical frame")
equal(calls.dt, 0.016, "update frame retains bounded delta time")

local firstSnapshot = assert(companion.world.snapshot())
equal(firstSnapshot.game, "red", "snapshot reports the real Gen 1 game")
check(firstSnapshot.tags.outdoor, "snapshot derives outdoor map tags")
check(firstSnapshot.cells[1].tags.grass, "snapshot derives grass cell tags")
check(firstSnapshot.cells[3].tags.door, "snapshot derives warp cell tags")
check(firstSnapshot.cells[4].tags.water, "snapshot derives water cell tags")
firstSnapshot.cells[1].kind = "corrupted-copy"
equal(companion.world.snapshot().cells[1].kind, "grass",
  "snapshot facade returns defensive copies")

state.player.px, state.player.py = 16, 16
state.player.cellX, state.player.cellY = 1, 1
companion:update(0.016, state)
equal(calls.world, 1, "player movement does not rebuild the whole world snapshot")

local beforeRevision = companion.revision
companion:worldChanged("first-edit")
companion:worldChanged("second-edit")
equal(companion.revision, beforeRevision + 1,
  "multiple block edits coalesce into one world revision")
companion:update(0.016, state)
equal(calls.world, 2, "coalesced edits dispatch one replacement snapshot")

local delta = companion:cameraDelta(state)
equal(delta.positionDelta.y, 2, "canonical camera delta is returned")
equal(delta.rotationDelta.yaw, 0.1, "camera rotation remains in radians")
equal(delta.fovDelta, 0.04, "camera FOV delta remains in radians")

local renderReport = companion:render("background", state)
check(renderReport, "background render dispatch returns a report")
equal(renderReport.called, 2, "both active render extensions are called")
equal(renderReport.failed, 1, "one extension draw fault is contained")
equal(renderReport.succeeded, 1, "later extension renders after an earlier fault")
equal(calls.faultyDispose, 1, "faulted extension is disposed exactly once")
equal(calls.healthyRender, 1, "healthy extension rendered")
equal(fakeVoxel3D.glassState, true, "host shader selector is restored after draw fault")
equal(pushCount, 1, "graphics state is pushed once for the phase")
equal(popCount, 1, "graphics state is popped once for the phase")
equal(graphicsState.color, "host", "graphics color state is restored")
equal(graphicsState.depth, "host", "graphics depth state is restored")
equal(graphicsState.blend, "host", "graphics blend state is restored")

local lateUpdates = 0
local late
late, err = provider.register({
  api = 1,
  id = "test.late-registration",
  update = function(frame)
    check(frame.dt >= 0, "late extension receives the canonical frame")
    lateUpdates = lateUpdates + 1
  end,
})
check(late, err or "late registration joins a running dispatcher")
check(late:is_active(), "late registration is active without a private context argument")
companion:update(0.02, state)
equal(lateUpdates, 1, "late extension runs on the next update")

companion:invalidate("test-invalidate")
equal(calls.invalidated, 1, "host invalidation reaches the healthy extension")
equal(calls.invalidateReason, "test-invalidate", "invalidation reason is canonical")
companion:dispose("test-dispose")
equal(calls.disposed, 1, "healthy extension is disposed exactly once")
equal(companion.state, nil, "adapter drops retained world state on dispose")
equal(companion.startContext, nil, "adapter drops retained activation context on dispose")
equal(love.update, sentinelUpdate, "adapter does not replace global callbacks")

local legacyMod = cleanMod()
local contaminated = false
function legacyMod:read(path)
  if contaminated and path == "lib/VoxelScene.lua" then
    return "local function __dsMod(name, statusKey) end\n"
  end
  return "-- clean\n"
end
local LegacyCompanion = assert(loadfile("lib/VoxelCompanion.lua"))(namespace(legacyMod))
local legacy = LegacyCompanion.new({ mod = legacyMod })
contaminated = true
local refused
refused, err = legacy.provider.register({
  api = 1,
  id = "test.must-refuse",
  update = function() end,
})
equal(refused, nil, "legacy-spliced host refuses companion registration")
contains(err, "legacy KFP splice markers detected in lib/VoxelScene.lua",
  "legacy refusal names the exact contaminated target")
contains(err, "reinstall a clean voxel host", "legacy refusal gives the recovery action")
equal(legacyMod.writes, 0, "legacy refusal scan never edits host files")

local cameraMat4 = { captured = {} }
function cameraMat4.identity() return { "identity" } end
function cameraMat4.perspective(fov, aspect, nearPlane, farPlane)
  cameraMat4.captured.fov = fov
  cameraMat4.captured.aspect = aspect
  return { "projection", nearPlane, farPlane }
end
function cameraMat4.lookAt(eye, focus, up)
  cameraMat4.captured.eye = eye
  cameraMat4.captured.focus = focus
  cameraMat4.captured.up = up
  return { "view" }
end
function cameraMat4.scale(x, y, z) return { "scale", x, y, z } end
function cameraMat4.mul(a, b) return { a, b } end

local cameraNamespace = {
  require = function(name)
    if name == "Mat4" then return cameraMat4 end
    if name == "VoxelState" then return { angle = 0, FOCAL = 1 } end
    return {}
  end,
}
local RealVoxel3D = assert(loadfile("lib/Voxel3D.lua"))(cameraNamespace)
RealVoxel3D.camera = {
  eye = { 0, 0, 0 },
  focus = { 0, 0, 10 },
  up = { 0, 1, 0 },
  fov = 1,
}
RealVoxel3D.setCompanionCameraDelta({
  positionDelta = { x = 100, y = 2, z = 0 },
  rotationDelta = { yaw = 0.1, pitch = 0, roll = 0 },
  fovDelta = 10,
})
RealVoxel3D.viewProjection(0, 0, 160, 144)
equal(cameraMat4.captured.eye[1], 32, "camera position delta is bounded")
equal(cameraMat4.captured.eye[2], 2, "camera position delta is additive")
check(cameraMat4.captured.focus[1] > cameraMat4.captured.eye[1],
  "radian yaw rotates the host focus direction")
local expectedFov = 1 + math.rad(30)
check(math.abs(cameraMat4.captured.fov - expectedFov) < 1e-9,
  "large FOV deltas are radian values bounded at the host boundary")

print(("%d checks passed (Voxel Companion API v1 BATTLE_ART host)"):format(checks))
