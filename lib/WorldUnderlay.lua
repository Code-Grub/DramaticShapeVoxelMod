-- One cheap, curved floor beneath the loaded voxel neighborhood.
--
-- The terrain remains authoritative: this mesh is drawn first at Y=-4 with
-- depth writes, so ordinary ground, recessed water and every structure cover
-- it naturally. Only literal holes expose it. Coarse tessellation is required
-- because V-CURVE bends vertices; one four-corner quad would remain two flat
-- triangles between its corners.

local V = ...

local Voxel3D = V.require("Voxel3D")
local Mat4 = V.require("Mat4")
local ModSetting = V.require("ModSetting")

local WorldUnderlay = {}

local STEP = 32
local RANGE = 32768
local HEIGHT = -4

WorldUnderlay.setting = ModSetting.new(
  "worldFill", "WORLD FILL",
  { "dark", "grass", "field", "soil", "water" },
  { "DARK", "GRASS", "FIELD", "SOIL", "WATER" })

local COLORS = {
  -- Matte dark grey, sampled from the inner perimeter / floor void of an
  -- indoor Pokémon Center (the band between the green sky and the wooden
  -- wall). Chosen as the default so holes and the void read as intentional
  -- negative space rather than a stray green seam.
  dark  = {  72 / 255,  72 / 255,  72 / 255, 1 }, -- #484848
  -- Sampled from the light path/grass reference used by the tileset. Keeping
  -- the two surfaces distinct prevents green seams beneath cities and paths
  -- while making holes in grassy routes blend into their immediate ground.
  field = { 223 / 255, 216 / 255, 164 / 255, 1 }, -- #DFD8A4
  grass = { 139 / 255, 197 / 255,  26 / 255, 1 }, -- #8BC51A
  soil  = { 119 / 255,  78 / 255,  33 / 255, 1 }, -- #774E21
  water = {  66 / 255,  55 / 255, 128 / 255, 1 }, -- #423780
}

local DEFAULT_FILL = "dark"

local cachedMesh = nil
local textures = {}

function WorldUnderlay.selected()
  return WorldUnderlay.setting:get() or DEFAULT_FILL
end

-- Dense where the camera can inspect the curve, increasingly coarse after
-- each doubled radius. A solid material has no texture scale to reveal those
-- outer cells, and V-CURVE has already carried them below the horizon.
local function axis()
  local positive, p, step, band = { 0 }, 0, STEP, 512
  while p < RANGE do
    p = math.min(RANGE, p + step)
    positive[#positive + 1] = p
    if p >= band then
      step = math.min(step * 2, 2048)
      band = band * 2
    end
  end
  local out = {}
  for i = #positive, 2, -1 do out[#out + 1] = -positive[i] end
  for i = 1, #positive do out[#out + 1] = positive[i] end
  return out
end

local function meshFor()
  if cachedMesh then return cachedMesh end
  local verts, indices = {}, {}
  local points = axis()
  local columns, rows = #points - 1, #points - 1
  for z = 1, #points do
    for x = 1, #points do
      verts[#verts + 1] = { points[x], HEIGHT, points[z], 0.5, 0.5, 1 }
    end
  end
  local stride = columns + 1
  for z = 0, rows - 1 do
    for x = 0, columns - 1 do
      local a = z * stride + x + 1
      indices[#indices + 1] = a
      indices[#indices + 1] = a + 1
      indices[#indices + 1] = a + stride + 1
      indices[#indices + 1] = a
      indices[#indices + 1] = a + stride + 1
      indices[#indices + 1] = a + stride
    end
  end
  cachedMesh = Voxel3D.newMesh(verts, indices)
  return cachedMesh
end

local function textureFor(archetype)
  if textures[archetype] then return textures[archetype] end
  if not (love and love.image and love.image.newImageData
          and love.graphics and love.graphics.newImage) then return nil end
  local ok, texture = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, unpack(COLORS[archetype] or COLORS.field))
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
  end)
  if ok then textures[archetype] = texture end
  return ok and texture or nil
end

function WorldUnderlay.draw(state, cx, cy)
  if not state then return false end
  local material = WorldUnderlay.selected()
  local mesh, texture = meshFor(), textureFor(material)
  if not (mesh and texture) then return false end
  -- A clean material layer: no voxel-grid seams or accidental glass-mask
  -- sampling. It still receives the same day tint and V-CURVE as terrain.
  Voxel3D.seams(false)
  Voxel3D.glass(false)
  -- The untextured plane follows the camera focus exactly. Its 65K-wide edge
  -- therefore stays beyond the practical far plane forever, without making a
  -- new GPU mesh at a map boundary or visibly sliding any pattern underfoot.
  Voxel3D.draw(mesh, texture, Mat4.translate(cx or 0, 0, cy or 0))
  Voxel3D.glass(true)
  Voxel3D.seams(true)
  return true
end

WorldUnderlay.COLORS = COLORS
WorldUnderlay.HEIGHT = HEIGHT
WorldUnderlay.STEP = STEP
WorldUnderlay.RANGE = RANGE

return WorldUnderlay
