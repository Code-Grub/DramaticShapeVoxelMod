package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"

-- The placement/classification surface is deliberately pure. Load it with
-- narrow renderer stubs so this suite remains runnable in the headless CI
-- interpreter without constructing the entire graphics mod a second time.
local stubs = {
  Mat4 = {}, Voxel3D = {}, VoxelState = { angle = 0 }, FirstPerson = {},
  WorldUnderlay = { STEP = 32, HEIGHT = -20,
                    enabled = function() return true end,
                    natureEnabled = function() return true end },
}
local V = {
  mod = { assets = {} },
  require = function(name) return assert(stubs[name], "unexpected module " .. name) end,
  data = function(name)
    return assert(loadfile(MOD_PATH .. "/data/" .. name .. ".lua"))()
  end,
}
local Props = assert(loadfile(MOD_PATH .. "/lib/WorldFillProps.lua"))(V)

T.eq(Props.biomeFor({ id = "VIRIDIAN_FOREST", def = {} }), nil,
  "Viridian Forest leaves its black void free of generated trees")
local function checkMaps(ids, expected, label)
  for _, id in ipairs(ids) do
    T.eq(Props.biomeFor({ id = id, def = {} }), expected,
      label .. " (" .. id .. ")")
  end
end
checkMaps({ "FUCHSIA_CITY", "VERMILION_CITY", "LAVENDER_TOWN",
            "CELADON_CITY", "SAFFRON_CITY", "ROUTE_6", "ROUTE_7",
            "ROUTE_8", "ROUTE_10", "ROUTE_12", "ROUTE_13", "ROUTE_14",
            "ROUTE_15", "ROUTE_16" }, "field",
  "fieldSafari routing")
checkMaps({ "ROUTE_3", "ROUTE_4", "ROUTE_9" }, "forest",
  "grassyForest routing")
T.eq(Props.biomeFor({ id = "SAFARI_ZONE_EAST", def = {} }), "field",
  "Safari Zone uses field props")
T.eq(Props.biomeFor({ id = "SAFARI_ZONE_EAST_REST_HOUSE",
                      def = { tileset = "FOREST" } }), nil,
  "Safari rest houses do not receive outdoor trees")
T.eq(Props.biomeFor({ id = "CINNABAR_ISLAND",
                      def = { tileset = "OVERWORLD" } }), nil,
  "Cinnabar Island keeps its cyan fill without generated trees")
T.eq(Props.biomeFor({ id = "SEAFOAM_ISLANDS_B4F",
                      def = { tileset = "CAVERN" } }), nil,
  "Seafoam interiors do not receive generated rocks")
local biomeData = V.data("world_fill_biomes")
T.check(biomeData.black.VIRIDIAN_FOREST
    and biomeData.black.SEAFOAM_ISLANDS_B4F,
  "problem locations select the black NATURE underlay")
T.check(not biomeData.black.CINNABAR_ISLAND,
  "Cinnabar keeps the cyan NATURE underlay")
checkMaps({ "ROUTE_23", "VICTORY_ROAD_1F", "VICTORY_ROAD_2F",
            "VICTORY_ROAD_3F", "INDIGO_PLATEAU" }, "rocky",
  "rocky routing")
checkMaps({ "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F", "MT_MOON_1F",
            "MT_MOON_B1F", "MT_MOON_B2F", "DIGLETTS_CAVE",
            "DIGLETTS_CAVE_ROUTE_2", "DIGLETTS_CAVE_ROUTE_11" }, nil,
  "dark cave exclusion")
T.eq(Props.biomeFor({ id = "PALLET_TOWN",
                      def = { tileset = "OVERWORLD" } }), "forest",
  "towns continue forest scenery beyond ROM tiles")
T.eq(Props.biomeFor({ id = "OAKS_LAB",
                      def = { tileset = "LAB" } }), nil,
  "ordinary interiors remain undecorated")

local v1, s1, jx1, jz1, b1 = Props.choice({ id = "ROUTE_1" }, 4, -7)
local v2, s2, jx2, jz2, b2 = Props.choice({ id = "ROUTE_1" }, 4, -7)
T.eq(table.concat({ v1, s1, jx1, jz1, b1 }, ","),
     table.concat({ v2, s2, jx2, jz2, b2 }, ","),
  "prop choice is deterministic per map/world cell")
T.check(v1 >= 1 and v1 <= 3 and b1 >= 0 and b1 <= 2,
  "choice stays inside authored variant and size-bucket ranges")
T.eq(s1, 1 + b1 * 0.5,
  "size buckets 0, 1 and 2 select 100%, 150% and 200% scale")
T.eq(jx1, 0, "every world cell stays centered without spacing jitter")
T.eq(jz1, 0, "every world cell stays centered without depth jitter")
T.eq(Props.radiusFor(160, 144, false), 11,
  "world-fill scenery keeps the normal mesh radius")
T.eq(Props.radiusFor(0, 0, true), 11,
  "free-camera scenery keeps its minimum mesh radius")

local state = {
  map = { id = "ROUTE_1", widthCells = 4, heightCells = 3, def = {} },
  neighbors = {
    { map = { id = "VIRIDIAN_CITY", widthCells = 2, heightCells = 2,
              def = {} }, ox = 64, oy = -32 },
  },
}
local rects = Props.loadedRects(state)
T.eq(Props.outsideLoaded(16, 16, rects), false,
  "props never occupy the root map rectangle")
T.eq(Props.outsideLoaded(80, -16, rects), false,
  "props never occupy a connected-map rectangle")
T.eq(Props.outsideLoaded(-64, -64, rects), true,
  "props remain eligible beyond loaded map rectangles")

T.finish("WORLD FILL PROPS")
