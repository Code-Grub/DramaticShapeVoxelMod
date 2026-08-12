-- Shared loader/cache for curated flat battle plates.

local V = ...
local BackdropImage = {}
local cache = {}

function BackdropImage.load(folder, file)
  if not file then return nil end
  local rel = ("assets/battle/front-static/%s/%s"):format(folder, file)
  if cache[rel] ~= nil then return cache[rel] or nil end
  local made
  local ok = pcall(function()
    local fs = love and love.filesystem
    local bytes = V.mod:read(rel)
    if type(bytes) == "string" and fs and fs.newFileData then
      local fileData = fs.newFileData(bytes, file)
      made = love.graphics.newImage(love.image.newImageData(fileData))
    else
      local path = V.mod.assets:path(rel)
      if not (fs and fs.getInfo and fs.getInfo(path)) then return end
      made = love.graphics.newImage(love.image.newImageData(path))
    end
    made:setFilter("linear", "linear")
    made:setWrap("clamp", "clamp")
  end)
  cache[rel] = (ok and made) or false
  return cache[rel] or nil
end

function BackdropImage.clear()
  for _, image in pairs(cache) do
    if image and image.release then pcall(image.release, image) end
  end
  cache = {}
end

return BackdropImage
