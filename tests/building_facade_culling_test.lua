local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end
local function eq(actual, expected, message)
  ok(actual == expected,
    message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local V = {
  require = function(name)
    assert(name == "BuildBudget", name)
    return { tick = function() end }
  end,
  data = function() return {} end,
}
local Buildings = assert(loadfile("lib/Buildings.lua"))(V)

local function upvalue(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
end

-- Exercise the actual emitter: of a single voxel's six shell faces, only
-- the +Z/south face is tagged as facade geometry.
local emit = upvalue(Buildings.build, "emit")
ok(type(emit) == "function", "building emitter is reachable for regression coverage")
local emitted = emit({
  W = 1, ytop = 0, zmin = 0, zmax = 0,
  at = function(x, y, z)
    if x == 0 and y == 0 and z == 0 then return 0 end
  end,
}, { ax = { [0] = 0 }, ay = { [0] = 0 } }, 16, 16)
local facadeCount = 0
for _, q in ipairs(emitted) do
  if q.facade then facadeCount = facadeCount + 1 end
end
eq(facadeCount, 1, "only the south-facing shell is tagged as facade")

local function scene(outdoor)
  return {
    outdoor = outdoor, shapeAt = {}, skip = {}, ground = {}, objectQuads = {},
    tileAt = setmetatable({}, { __index = function() return 1 end }),
  }
end
local function map(withDoor)
  return {
    isDoorTileCell = function(_, cx, cy)
      return withDoor and cx == 1 and cy == 1
    end,
  }
end
local quads = {
  {
    { 0, 0, 8 }, { 8, 0, 8 }, { 8, 8, 8 }, { 0, 8, 8 },
    uv = {}, shade = 0.9, facade = true,
  },
  {
    { 8, 0, 8 }, { 8, 0, 0 }, { 8, 8, 0 }, { 8, 8, 8 },
    uv = {}, shade = 0.8,
  },
}

local enterable = scene(true)
Buildings.stamp(enterable, map(true), quads, 0, 0, 4, 4, {})
eq(enterable.objectQuads[1].shade, -0.9,
  "an enterable exterior facade carries the one-sided marker")
eq(enterable.objectQuads[2].shade, 0.8,
  "the same building's side wall stays ordinary")

local scenery = scene(true)
Buildings.stamp(scenery, map(false), quads, 0, 0, 4, 4, {})
eq(scenery.objectQuads[1].shade, 0.9,
  "the same template at a scenery placement stays double-sided")

local interior = scene(false)
Buildings.stamp(interior, map(true), quads, 0, 0, 4, 4, {})
eq(interior.objectQuads[1].shade, 0.9,
  "interior building/furniture models are never marked")

local shader = assert(io.open("lib/Voxel3D.lua", "rb")):read("*a")
ok(shader:find("vFacadeBack", 1, true)
   and shader:find("step%(eye.z, w.z %- 0.0001%)"),
  "scene shader discards marked facades only from behind")

print(("%d checks passed (enterable building facade culling)"):format(checks))
