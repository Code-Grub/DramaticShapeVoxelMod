package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local profile = assert(loadfile(MOD_PATH .. "/data/voxel_heights.lua"))()
local dojo = assert(profile.tilesets.DOJO, "missing DOJO tileset profile")
local lab = assert(profile.maps.OAKS_LAB, "missing Oak's Lab map profile")

T.eq(dojo.can, nil, "shared DOJO tileset does not alter Fighting Dojo cans")
T.eq(dojo.top_tiles, nil,
  "shared DOJO tileset does not alter Fighting Dojo wall tops")
T.eq(table.concat(lab.can, ","), "11,12,27,28",
  "Oak's Lab waste bin uses all four can tiles")
T.eq(lab.can_cap, 9, "Oak's Lab can retains the open rim")
T.eq(lab.can_base, 4, "Oak's Lab can has the authored base radius")
T.eq(lab.can_height, 9, "Oak's Lab can has the authored height")
T.eq(lab.can_well, 5, "Oak's Lab can has an inset dark well")
T.eq(lab.can_taper, 4, "Oak's Lab can tapers toward its base")
T.eq(table.concat(lab.wall, ","), "52,67,82,83",
  "Oak's Lab wall scroll facade tiles remain authored walls")
for _, tile in ipairs(lab.wall) do
  T.eq(lab.top_tiles[tile], 5,
    "scroll tile " .. tile .. " uses the neighboring wall top")
end

T.finish("OAK'S LAB PROFILE")
