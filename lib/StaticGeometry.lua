-- Immutable geometry source for persistent voxel meshes.
--
-- Runtime Map objects deliberately share their definitions with Game.data.
-- Cut, card-key doors and scripts therefore mutate def.blocks in place, while
-- overworld mods append transient NPC/Pokemon records to def.objects.  Neither
-- kind of session state belongs in a persistent static-mesh key.
--
-- Capture the final modded registries once, after `mods.loaded`, before a save
-- can enter the overworld.  Disk meshes are generated from these private map
-- objects.  A live map may reuse them only while every geometry-bearing field
-- still equals the snapshot; a genuinely edited map is meshed in RAM and never
-- overwrites the static record.

local V = ...

local StaticGeometry = {}

local snapshot, maps = nil, {}

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do
    out[clone(k, seen)] = clone(v, seen)
  end
  return out
end

local function sameList(a, b)
  if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
  for i = 1, #a do
    local av, bv = a[i], b[i]
    if type(av) == "table" or type(bv) == "table" then
      if not sameList(av, bv) then return false end
    elseif av ~= bv then
      return false
    end
  end
  return true
end

local function sameScalarList(a, b)
  a, b = a or {}, b or {}
  return sameList(a, b)
end

function StaticGeometry.capture(data)
  if snapshot or not (data and data.maps and data.tilesets) then return false end
  snapshot = { maps = clone(data.maps), tilesets = clone(data.tilesets) }
  maps = {}
  return true
end

function StaticGeometry.available()
  return snapshot ~= nil
end

function StaticGeometry.data()
  return snapshot
end

-- A renderer-free Map is sufficient for Structures/ChunkMesher: those paths
-- query blocks, collision properties and tileset art, never TileRenderer state.
function StaticGeometry.map(id)
  if not snapshot then return nil end
  if maps[id] then return maps[id] end
  local def = snapshot.maps[id]
  local tileset = def and snapshot.tilesets[def.tileset]
  if not (def and tileset) then return nil end
  local Map = require("src.world.Map")
  local map = Map.new(def, tileset)
  maps[id] = map
  return map
end

-- Keep this list intentionally narrower than the whole registry. Objects,
-- warps, signs, connections, palette animation and other gameplay/presentation
-- data do not alter emitted vertices. Everything Structures does read is here.
function StaticGeometry.matches(map)
  if not (snapshot and map and map.id and map.def and map.tileset) then return false end
  local def = snapshot.maps[map.id]
  local tileset = def and snapshot.tilesets[def.tileset]
  if not (def and tileset) then return false end
  local liveDef, liveTs = map.def, map.tileset
  if liveDef.tileset ~= def.tileset or liveDef.width ~= def.width
     or liveDef.height ~= def.height or liveDef.borderBlock ~= def.borderBlock
     or liveDef.outdoor ~= def.outdoor or not sameList(liveDef.blocks, def.blocks) then
    return false
  end
  return liveTs.id == tileset.id
     and liveTs.image == tileset.image
     and liveTs.imageWidth == tileset.imageWidth
     and liveTs.imageHeight == tileset.imageHeight
     and liveTs.tilesPerRow == tileset.tilesPerRow
     and liveTs.trueColor == tileset.trueColor
     and liveTs.grassTile == tileset.grassTile
     and sameList(liveTs.blocks, tileset.blocks)
     and sameScalarList(liveTs.walkable, tileset.walkable)
     and sameScalarList(liveTs.doorTiles, tileset.doorTiles)
     and sameScalarList(liveTs.waterTiles, tileset.waterTiles)
     and sameScalarList(liveTs.shoreTiles, tileset.shoreTiles)
end

-- The private snapshot map is itself the canonical source. Runtime maps return
-- it only when eligible, which lets Disk.fingerprint ignore NPC/object churn.
function StaticGeometry.source(map)
  local canonical = map and StaticGeometry.map(map.id) or nil
  if map == canonical or StaticGeometry.matches(map) then return canonical end
  return nil
end

return StaticGeometry
