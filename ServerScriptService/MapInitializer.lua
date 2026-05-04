local Workspace = game:GetService("Workspace")

local MAP_FOLDER_NAME = "map"

local mapFolder = Workspace:FindFirstChild(MAP_FOLDER_NAME)
if not mapFolder then
	error("MapInitializer: could not find Workspace." .. MAP_FOLDER_NAME)
end

Workspace:SetAttribute("CurrentMapName", MAP_FOLDER_NAME)
Workspace:SetAttribute("CurrentMapTheme", MAP_FOLDER_NAME)
print("MapInitializer: using existing Workspace." .. MAP_FOLDER_NAME)
