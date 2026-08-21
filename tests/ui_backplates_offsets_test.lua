package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"

local V = { mod = { id = "BATTLE_ART_VOXEL_FORK" } }
local ModSetting = assert(loadfile(MOD_PATH .. "/lib/ModSetting.lua"))(V)
V.require = function(name)
  assert(name == "ModSetting", "unexpected module " .. tostring(name))
  return ModSetting
end

local Backplates = assert(loadfile(MOD_PATH .. "/lib/UiBackplates.lua"))(V)
local offset = Backplates.backdropOffset

T.eq(#offset.values, 21, "BG Y-OFFSET has 21 non-negative choices")
T.eq(offset.values[1], 0, "BG Y-OFFSET begins at zero")
T.eq(offset.values[6], 100, "BG Y-OFFSET contains 100 pixels")
T.eq(offset.values[21], 400, "BG Y-OFFSET ends at 400 pixels")
T.eq(offset:get(), 100, "BG Y-OFFSET defaults to 100 pixels")
T.eq(Backplates.backdropOffsetPixels(), 100,
  "background rendering receives the 100-pixel default")

T.finish("UI BACKPLATE OFFSETS")
