-- Import the original, independently authored Succubus tail and put it in
-- the breast-size master's back-piece group. The historical Demon source
-- calls the tail "cola", the wings "Alas", and the garment "Base".
--
-- Unlike a flood fill of the flattened fitted outfit, this preserves the
-- whole tail root without pulling belt/hip pixels into the back layer. Only
-- tail pixels not covered by the authored Succubus Base are removed from the
-- three fitted outfit layers; the complete tail is then rendered behind the
-- body by the runtime builder.
--
-- Usage:
--   aseprite -b breast-master.aseprite \
--     --script-param tail-source=/path/to/Demon.aseprite \
--     --script-param output=/path/to/fixed-master.aseprite \
--     --script separate_succubus_tail.lua

local target = app.activeSprite
if not target then error("No active breast-size master") end

local sourcePath = app.params["tail-source"]
if not sourcePath or sourcePath == "" then
  error("Missing --script-param tail-source=/path/to/Demon.aseprite")
end
local output = app.params["output"] or target.filename
if output == "" then error("Missing output path") end

local function child(parent, name)
  for _, layer in ipairs(parent.layers) do
    if layer.name == name then return layer end
  end
  return nil
end

local function path(root, names)
  local current = root
  for _, name in ipairs(names) do
    current = child(current, name)
    if not current then return nil end
  end
  return current
end

local character = child(target, "Character")
local backGroup = character and child(character, "Back Pieces - match outfit")
local targetBody = character and child(character, "Body")
if not backGroup or not backGroup.isGroup then
  error("Missing Character/Back Pieces - match outfit group")
end
if not targetBody or targetBody.isGroup then
  error("Missing Character/Body layer")
end

local sizeGroups = {
  child(target, "Outfits for small boobs"),
  child(target, "Outfits for normal boobs"),
  child(target, "Outfits for big boobs"),
}
local fittedLayers = {}
for index, group in ipairs(sizeGroups) do
  if not group or not group.isGroup then
    error("Missing fitted outfit group " .. tostring(index))
  end
  local fitted = child(group, "Succubus")
  if not fitted or fitted.isGroup then
    error("Missing Succubus image layer in " .. group.name)
  end
  table.insert(fittedLayers, fitted)
end

local source = app.open(sourcePath)
if not source then error("Could not open authored tail source: " .. sourcePath) end
if source.colorMode ~= target.colorMode then
  error("Tail source and target use different color modes")
end
if #source.frames ~= #target.frames then
  error("Tail source and target have different frame counts")
end

local sourceRoot = path(source, { "Group 1 Copy Copy" })
local succubus = sourceRoot and child(sourceRoot, "Sucube")
local sourceBody = sourceRoot and child(sourceRoot, "Body")
local sourceTail = succubus and child(succubus, "cola")
local sourceBase = succubus and child(succubus, "Base")
if not sourceBody or not sourceTail or not sourceBase then
  error("Authored source is missing Body or Sucube/{cola,Base}")
end

local transparent = app.pixelColor.rgba(0, 0, 0, 0)

local function pixelAt(cel, worldX, worldY)
  if not cel then return transparent end
  local x = worldX - cel.position.x
  local y = worldY - cel.position.y
  if x < 0 or y < 0 or x >= cel.image.width or y >= cel.image.height then
    return transparent
  end
  return cel.image:getPixel(x, y)
end

local oldTail = child(backGroup, "Succubus Tail")
local importedPerFrame = {}
local clearedPerFrame = {}

app.transaction("Import authored Succubus tail behind body", function()
  if oldTail then target:deleteLayer(oldTail) end

  local tailLayer = target:newLayer()
  tailLayer.name = "Succubus Tail"
  tailLayer.parent = backGroup
  tailLayer.isVisible = false

  for frameNumber = 1, #target.frames do
    local sourceTailCel = sourceTail:cel(frameNumber)
    local sourceBaseCel = sourceBase:cel(frameNumber)
    local sourceBodyCel = sourceBody:cel(frameNumber)
    local targetBodyCel = targetBody:cel(frameNumber)
    if not sourceTailCel or not sourceBaseCel or not sourceBodyCel or not targetBodyCel then
      error("Missing source/target cel in frame " .. frameNumber)
    end

    local offsetX = targetBodyCel.position.x - sourceBodyCel.position.x
    local offsetY = targetBodyCel.position.y - sourceBodyCel.position.y
    local imported = 0
    local clearPoints = {}

    for y = 0, sourceTailCel.image.height - 1 do
      for x = 0, sourceTailCel.image.width - 1 do
        local tailPixel = sourceTailCel.image:getPixel(x, y)
        if app.pixelColor.rgbaA(tailPixel) > 0 then
          imported = imported + 1
          local sourceX = sourceTailCel.position.x + x
          local sourceY = sourceTailCel.position.y + y
          if app.pixelColor.rgbaA(pixelAt(sourceBaseCel, sourceX, sourceY)) == 0 then
            table.insert(clearPoints, Point(sourceX + offsetX, sourceY + offsetY))
          end
        end
      end
    end

    if imported < 210 or imported > 250 then
      error(string.format("Unexpected authored tail size in frame %d: %d", frameNumber, imported))
    end

    target:newCel(
      tailLayer,
      target.frames[frameNumber],
      sourceTailCel.image:clone(),
      Point(sourceTailCel.position.x + offsetX, sourceTailCel.position.y + offsetY)
    )

    local cleared = 0
    for _, fittedLayer in ipairs(fittedLayers) do
      local fittedCel = fittedLayer:cel(frameNumber)
      if not fittedCel then error("Missing fitted Succubus cel " .. frameNumber) end
      local image = fittedCel.image:clone()
      local layerCleared = 0
      for _, point in ipairs(clearPoints) do
        local x = point.x - fittedCel.position.x
        local y = point.y - fittedCel.position.y
        if x >= 0 and y >= 0 and x < image.width and y < image.height then
          if app.pixelColor.rgbaA(image:getPixel(x, y)) > 0 then
            image:drawPixel(x, y, transparent)
            layerCleared = layerCleared + 1
          end
        end
      end
      fittedCel.image = image
      if cleared == 0 then
        cleared = layerCleared
      elseif cleared ~= layerCleared then
        error(string.format("Tail clear differs by breast size in frame %d", frameNumber))
      end
    end

    if cleared < 180 or cleared > 230 then
      error(string.format("Unexpected visible tail size in frame %d: %d", frameNumber, cleared))
    end
    importedPerFrame[frameNumber] = imported
    clearedPerFrame[frameNumber] = cleared
  end
end)

target:saveAs(output)
for frameNumber = 1, #target.frames do
  print(string.format(
    "Succubus tail frame %d: imported %d authored pixels; removed %d visible pixels from each fit",
    frameNumber,
    importedPerFrame[frameNumber],
    clearedPerFrame[frameNumber]
  ))
end
print("Saved corrected master: " .. output)
