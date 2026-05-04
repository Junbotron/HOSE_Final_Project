local ENABLE_RUNTIME_MAP_BUILD = true

if not ENABLE_RUNTIME_MAP_BUILD then
	print("MapInitializer: runtime map build disabled for Workspace blockout mode")
	return
end

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Builder = require(ServerStorage:WaitForChild("MapSystem"):WaitForChild("Builder"))
local Registry = require(ServerStorage:WaitForChild("MapSystem"):WaitForChild("Registry"))

local SELECTED_MAP_NAME = "UltimateTagArena"

local function ensureMapsFolder()
	local folder = Workspace:FindFirstChild("Maps")
	if folder then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "Maps"
	folder.Parent = Workspace
	return folder
end

local function clearMaps(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function removeExternalSpawnLocations(mapsFolder)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") and not descendant:IsDescendantOf(mapsFolder) then
			descendant:Destroy()
		end
	end
end

local function loadMap(mapName)
	local mapsFolder = ensureMapsFolder()
	clearMaps(mapsFolder)

	local definition = Registry:GetMap(mapName)
	if not definition then
		error("Map definition not found: " .. tostring(mapName))
	end

	local mapModel = Instance.new("Model")
	mapModel.Name = definition.name
	mapModel.Parent = mapsFolder

	local builder = Builder.new(mapModel)
	builder:ApplyLighting(definition.lighting)
	builder:BuildMap(definition)
	removeExternalSpawnLocations(mapsFolder)

	Workspace:SetAttribute("CurrentMapName", definition.name)
	Workspace:SetAttribute("CurrentMapTheme", definition.theme)
	print("Loaded map:", definition.name)
	print("Available maps:", table.concat(Registry:ListMaps(), ", "))
	return mapModel
end

local mapToLoad = Registry:GetMap(SELECTED_MAP_NAME) and SELECTED_MAP_NAME or Registry:GetDefaultMapName()

if not mapToLoad then
	error("No map definitions found in Registry or ServerStorage/MapDefinitions")
end

loadMap(mapToLoad)
