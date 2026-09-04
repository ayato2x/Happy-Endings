local sprite = app.activeSprite
if not sprite then error("Open an Aseprite file before running this script") end

local outputPath = app.params["output"] or ""
local selection = app.params["layers"] or ""
if outputPath == "" then error("Missing --script-param output=<png>") end
if selection == "" then error("Missing --script-param layers=<path;path>") end

local function normalize(value)
  return (value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split(value, delimiter)
  local result = {}
  for part in string.gmatch(value, "[^" .. delimiter .. "]+") do
    table.insert(result, normalize(part))
  end
  return result
end

local function findChild(parent, name)
  for _, layer in ipairs(parent.layers) do
    if normalize(layer.name) == name then return layer end
  end
  return nil
end

local function resolve(path)
  local parent = sprite
  local found = nil
  for _, part in ipairs(split(path, "/")) do
    found = findChild(parent, part)
    if not found then error("Layer path not found: " .. path) end
    parent = found
  end
  return found
end

local function hideTree(layers)
  for _, layer in ipairs(layers) do
    layer.isVisible = false
    if layer.isGroup then hideTree(layer.layers) end
  end
end

local function showAncestors(layer)
  local current = layer
  while current and current ~= sprite do
    current.isVisible = true
    current = current.parent
  end
end

hideTree(sprite.layers)
for _, path in ipairs(split(selection, ";")) do
  showAncestors(resolve(path))
end

local sheet = Image(sprite.width * #sprite.frames, sprite.height, ColorMode.RGB)
sheet:clear()
for index, frame in ipairs(sprite.frames) do
  sheet:drawSprite(sprite, frame, Point((index - 1) * sprite.width, 0))
end
sheet:saveAs(outputPath)
