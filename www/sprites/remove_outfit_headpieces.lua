-- Permanently remove retired outfit-owned head art from the mix-and-match
-- Aseprite master. Run with the master already opened by Aseprite CLI:
--
--   aseprite -b master.aseprite --script remove_outfit_headpieces.lua

local sprite = app.activeSprite
if not sprite then
  error("No active Aseprite document")
end

local cutoffs = {
  ["Succubus"] = 35,
  ["Dress V2"] = 40,
}

local found = {}
local changedPixels = {}

local function clearLayerHead(layer, cutoff)
  found[layer.name] = true
  changedPixels[layer.name] = 0

  for _, cel in ipairs(layer.cels) do
    local image = cel.image:clone()
    local origin = cel.position
    local changed = 0

    for imageY = 0, image.height - 1 do
      if origin.y + imageY < cutoff then
        for imageX = 0, image.width - 1 do
          local pixel = image:getPixel(imageX, imageY)
          local alpha = app.pixelColor.rgbaA(pixel)
          if alpha > 0 then
            image:drawPixel(imageX, imageY, app.pixelColor.rgba(0, 0, 0, 0))
            changed = changed + 1
          end
        end
      end
    end

    if changed > 0 then
      cel.image = image
      changedPixels[layer.name] = changedPixels[layer.name] + changed
    end
  end
end

local function visit(layers)
  for _, layer in ipairs(layers) do
    local cutoff = cutoffs[layer.name]
    if cutoff then
      if layer.isGroup then
        error("Expected an image layer named " .. layer.name .. ", found a group")
      end
      clearLayerHead(layer, cutoff)
    end
    if layer.isGroup then
      visit(layer.layers)
    end
  end
end

app.transaction("Remove Succubus and Dress V2 headpieces", function()
  visit(sprite.layers)
end)

for layerName, _ in pairs(cutoffs) do
  if not found[layerName] then
    error("Missing required outfit layer: " .. layerName)
  end
  print(layerName .. ": cleared " .. changedPixels[layerName] .. " head pixels")
end

sprite:saveAs(sprite.filename)
