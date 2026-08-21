local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end

package.loaded["src.core.Version"] = { engine = "0.2.7" }
package.loaded["src.core.Platform"] = { detect = function()
  return { os = "Windows" }
end }

-- Disk.stats only needs to know the runtime supports cache primitives; these
-- tests do not encode or upload a mesh.
local runtimeLove = love or {}
love = setmetatable({
  filesystem = false,
  data = { pack = function() end, unpack = function() end,
           newByteData = function() end, compress = function() end,
           decompress = function() end },
  graphics = { newMesh = function() end },
}, { __index = runtimeLove })

local bytes = {}
local persists = true
local storage = {}
function storage:list(_, prefix)
  local out = {}
  for key in pairs(bytes) do
    if key:sub(1, #prefix) == prefix then out[#out + 1] = key end
  end
  return out
end
function storage:readBytes(_, key) return bytes[key] end
function storage:writeBytes(_, key, value)
  if persists then bytes[key] = value end
  return true
end

local V = { mod = { storage = storage } }
function V.require(name)
  return assert(({ BuildBudget={check=function() end}, StaticGeometry={} })[name], name)
end

local Disk = assert(loadfile("lib/VoxelMeshDisk.lua"))(V)
local bound, result = pcall(Disk.bind, {save={version="red-test"}}, false)
ok(bound and result, "storage round-trip probe is a scoped local and binds")

bytes["cache/static-mesh-v2/PALLET/deco"] = "decorations"
bytes["cache/static-mesh-v2/PALLET/body-terrain"] = "body"
bytes["cache/static-mesh-v2/PALLET/full-terrain"] = "full"
local stats = Disk.stats()
ok(stats.maps == 1 and stats.files == 3, "stats groups all products by map")
ok(stats.aux == 1 and stats.body == 1 and stats.full == 1,
  "Windows-safe deco product is reported as AUX")

ok(Disk.purge() == 3, "purge invalidates the active storage facade")
ok(bytes["cache/static-mesh-v2/PALLET/full-terrain"] == "",
  "purged storage body cannot be reused")

persists = false
bound, result = pcall(Disk.bind, {save={version="red-test"}}, false)
ok(bound and not result, "lying storage backend fails open instead of throwing")

print(("%d checks passed (voxel storage binding)"):format(checks))
