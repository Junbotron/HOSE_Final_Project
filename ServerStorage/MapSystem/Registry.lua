local ServerStorage = game:GetService("ServerStorage")

local Registry = {}

local DEFINITIONS_FOLDER_NAME = "MapDefinitions"
local DEFAULT_MAP_NAME = "ResearchFacility"
local BUILTIN_DEFINITIONS = {
	UltimateTagArena = {
		name = "UltimateTagArena",
		theme = "Bright Vertical Arena",
		lighting = {
			Ambient = Color3.fromRGB(245, 245, 245),
			OutdoorAmbient = Color3.fromRGB(235, 235, 235),
			Brightness = 3,
			ClockTime = 13.5,
			FogColor = Color3.fromRGB(255, 255, 255),
			FogStart = 300,
			FogEnd = 1000,
		},
		rooms = {
			{
				name = "MainArena",
				signText = "ULTIMATE TAG ARENA",
				center = Vector3.new(0, 0, 0),
				size = Vector3.new(160, 1, 120),
				wallHeight = 42,
				floorMaterial = Enum.Material.SmoothPlastic,
				floorColor = Color3.fromRGB(236, 236, 236),
				wallMaterial = Enum.Material.SmoothPlastic,
				wallColor = Color3.fromRGB(247, 247, 247),
				ceilingMaterial = Enum.Material.SmoothPlastic,
				ceilingColor = Color3.fromRGB(252, 252, 252),
				openings = {
					east = {
						{ offset = 38, width = 14, height = 14, bottom = 0 },
					},
					west = {
						{ offset = -34, width = 8, height = 10, bottom = 0 },
						{ offset = 34, width = 8, height = 10, bottom = 0 },
					},
				},
			},
		},
		scaffolds = {
			{ name = "Tower_NW", position = Vector3.new(-36, 0, -22), size = Vector3.new(18, 34, 12), deckLevels = { 7, 18, 29 } },
			{ name = "Tower_NE", position = Vector3.new(36, 0, -22), size = Vector3.new(18, 34, 12), deckLevels = { 7, 18, 29 } },
			{ name = "Tower_SW", position = Vector3.new(-36, 0, 22), size = Vector3.new(18, 34, 12), deckLevels = { 7, 18, 29 } },
			{ name = "Tower_SE", position = Vector3.new(36, 0, 22), size = Vector3.new(18, 34, 12), deckLevels = { 7, 18, 29 } },
			{ name = "CoreRig", position = Vector3.new(0, 0, 0), size = Vector3.new(28, 30, 18), deckLevels = { 8, 17, 26 } },
		},
		doors = {
			{ name = "Door_West_North", label = "Bulkhead", position = Vector3.new(-80, 0, -34), axis = "Z", width = 8, height = 10, holdDuration = 3, loaderText = "Cranking bulkhead open", closeActionText = "Slam Shut", promptHeight = 4.5 },
			{ name = "Door_West_South", label = "Bulkhead", position = Vector3.new(-80, 0, 34), axis = "Z", width = 8, height = 10, holdDuration = 3, loaderText = "Cranking bulkhead open", closeActionText = "Slam Shut", promptHeight = 4.5 },
			{ name = "Vent_Shutter_North", label = "Vent Shutter", position = Vector3.new(-12, 1, -38), axis = "X", width = 4, height = 3, holdDuration = 3, loaderText = "Opening vent shutter", closeActionText = "Slam Shut", promptHeight = 2.4, promptOffset = 5 },
			{ name = "Vent_Shutter_South", label = "Vent Shutter", position = Vector3.new(12, 1, 38), axis = "X", width = 4, height = 3, holdDuration = 3, loaderText = "Opening vent shutter", closeActionText = "Slam Shut", promptHeight = 2.4, promptOffset = 5 },
		},
		vents = {
			{ name = "VentFrameNorth", position = Vector3.new(-12, 0, -38), width = 4, height = 3, bottom = 1, rotation = 0 },
			{ name = "VentFrameSouth", position = Vector3.new(12, 0, 38), width = 4, height = 3, bottom = 1, rotation = 180 },
		},
		cover = {
			{ name = "Bridge_Lower_North", position = Vector3.new(0, 17, -22), size = Vector3.new(56, 1, 4), material = Enum.Material.DiamondPlate, color = Color3.fromRGB(250, 250, 250) },
			{ name = "Bridge_Lower_South", position = Vector3.new(0, 17, 22), size = Vector3.new(56, 1, 4), material = Enum.Material.DiamondPlate, color = Color3.fromRGB(250, 250, 250) },
			{ name = "Bridge_Upper_North", position = Vector3.new(0, 28, -22), size = Vector3.new(56, 1, 3), material = Enum.Material.DiamondPlate, color = Color3.fromRGB(250, 250, 250) },
			{ name = "Bridge_Upper_South", position = Vector3.new(0, 28, 22), size = Vector3.new(56, 1, 3), material = Enum.Material.DiamondPlate, color = Color3.fromRGB(250, 250, 250) },
			{ name = "CorePlatformLow", position = Vector3.new(0, 11, 0), size = Vector3.new(20, 1, 10), material = Enum.Material.DiamondPlate, color = Color3.fromRGB(252, 252, 252) },
			{ name = "CorePlatformMid", position = Vector3.new(0, 21, 0), size = Vector3.new(16, 1, 8), material = Enum.Material.DiamondPlate, color = Color3.fromRGB(252, 252, 252) },
			{ name = "Beam_North_Run", position = Vector3.new(0, 31, -6), size = Vector3.new(42, 1, 2), material = Enum.Material.Metal, color = Color3.fromRGB(232, 232, 232) },
			{ name = "Beam_South_Run", position = Vector3.new(0, 31, 6), size = Vector3.new(42, 1, 2), material = Enum.Material.Metal, color = Color3.fromRGB(232, 232, 232) },
			{ name = "Ramp_West_1", position = Vector3.new(-55, 6, -8), size = Vector3.new(20, 1.2, 6), material = Enum.Material.Metal, color = Color3.fromRGB(242, 242, 242), rotation = Vector3.new(0, 0, -24) },
			{ name = "Ramp_East_1", position = Vector3.new(55, 6, 8), size = Vector3.new(20, 1.2, 6), material = Enum.Material.Metal, color = Color3.fromRGB(242, 242, 242), rotation = Vector3.new(0, 0, 24) },
			{ name = "Ramp_Center_2A", position = Vector3.new(-12, 16, 0), size = Vector3.new(18, 1.2, 5), material = Enum.Material.Metal, color = Color3.fromRGB(240, 240, 240), rotation = Vector3.new(0, 0, -26) },
			{ name = "Ramp_Center_2B", position = Vector3.new(12, 16, 0), size = Vector3.new(18, 1.2, 5), material = Enum.Material.Metal, color = Color3.fromRGB(240, 240, 240), rotation = Vector3.new(0, 0, 26) },
			{ name = "Ramp_Center_3A", position = Vector3.new(-10, 25, -12), size = Vector3.new(18, 1.2, 5), material = Enum.Material.Metal, color = Color3.fromRGB(240, 240, 240), rotation = Vector3.new(0, 0, -26) },
			{ name = "Ramp_Center_3B", position = Vector3.new(10, 25, 12), size = Vector3.new(18, 1.2, 5), material = Enum.Material.Metal, color = Color3.fromRGB(240, 240, 240), rotation = Vector3.new(0, 0, 26) },
			{ name = "CrawlBayNorth_LeftWall", position = Vector3.new(-16, 2, -34), size = Vector3.new(1, 4, 10), material = Enum.Material.Metal, color = Color3.fromRGB(230, 230, 230) },
			{ name = "CrawlBayNorth_RightWall", position = Vector3.new(-8, 2, -34), size = Vector3.new(1, 4, 10), material = Enum.Material.Metal, color = Color3.fromRGB(230, 230, 230) },
			{ name = "CrawlBayNorth_Roof", position = Vector3.new(-12, 4.5, -34), size = Vector3.new(8, 1, 10), material = Enum.Material.Metal, color = Color3.fromRGB(245, 245, 245) },
			{ name = "CrawlBaySouth_LeftWall", position = Vector3.new(8, 2, 34), size = Vector3.new(1, 4, 10), material = Enum.Material.Metal, color = Color3.fromRGB(230, 230, 230) },
			{ name = "CrawlBaySouth_RightWall", position = Vector3.new(16, 2, 34), size = Vector3.new(1, 4, 10), material = Enum.Material.Metal, color = Color3.fromRGB(230, 230, 230) },
			{ name = "CrawlBaySouth_Roof", position = Vector3.new(12, 4.5, 34), size = Vector3.new(8, 1, 10), material = Enum.Material.Metal, color = Color3.fromRGB(245, 245, 245) },
			{ name = "CrateStack_A_Base", position = Vector3.new(-58, 2, 18), size = Vector3.new(6, 4, 6), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(170, 146, 108) },
			{ name = "CrateStack_A_Top", position = Vector3.new(-58, 6, 18), size = Vector3.new(4, 4, 4), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(176, 152, 114) },
			{ name = "CrateStack_B_Base", position = Vector3.new(58, 2, -18), size = Vector3.new(6, 4, 6), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(170, 146, 108) },
			{ name = "CrateStack_B_Top", position = Vector3.new(58, 6, -18), size = Vector3.new(4, 4, 4), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(176, 152, 114) },
			{ name = "CrateLine_1", position = Vector3.new(-10, 1.5, 10), size = Vector3.new(4, 3, 4), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(173, 149, 110) },
			{ name = "CrateLine_2", position = Vector3.new(8, 1.5, -12), size = Vector3.new(4, 3, 4), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(173, 149, 110) },
			{ name = "CrateLine_3", position = Vector3.new(24, 1.5, 14), size = Vector3.new(5, 3, 5), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(173, 149, 110) },
			{ name = "CrateLine_4", position = Vector3.new(-26, 1.5, -14), size = Vector3.new(5, 3, 5), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(173, 149, 110) },
		},
		crawlBlockers = {
			{ name = "CrawlOnlyBlockNorth", position = Vector3.new(-12, 2.5, -34), size = Vector3.new(6, 5, 8) },
			{ name = "CrawlOnlyBlockSouth", position = Vector3.new(12, 2.5, 34), size = Vector3.new(6, 5, 8) },
		},
		tasks = {
			{ name = "Generator_NorthWest", type = "GeneratorHack", label = "Generator Alpha", position = Vector3.new(-36, 0, -40), holdDuration = 3, loaderText = "Starting generator" },
			{ name = "Generator_NorthEast", type = "GeneratorHack", label = "Generator Beta", position = Vector3.new(36, 0, -40), holdDuration = 3, loaderText = "Starting generator" },
			{ name = "Generator_SouthWest", type = "GeneratorHack", label = "Generator Gamma", position = Vector3.new(-36, 0, 40), holdDuration = 3, loaderText = "Starting generator" },
			{ name = "Generator_SouthEast", type = "GeneratorHack", label = "Generator Delta", position = Vector3.new(36, 0, 40), holdDuration = 3, loaderText = "Starting generator" },
			{ name = "Valve_Core_Low", type = "ValveTurn", position = Vector3.new(0, 0, -12), turnsRequired = 3 },
			{ name = "Valve_Core_Mid", type = "ValveTurn", position = Vector3.new(0, 17, 12), turnsRequired = 3 },
			{ name = "Valve_Core_High", type = "ValveTurn", position = Vector3.new(0, 26, 0), turnsRequired = 3 },
		},
		exitDoor = {
			name = "ExitDoor_Main",
			label = "Emergency Exit",
			position = Vector3.new(80, 0, 38),
			axis = "Z",
			width = 14,
			height = 14,
			holdDuration = 10,
			loaderText = "Turning release wheel",
			lightPosition = Vector3.new(80, 17, 38),
			escapeZonePosition = Vector3.new(89, 4, 38),
			escapeZoneSize = Vector3.new(12, 8, 16),
			promptPositions = { Vector3.new(74, 6, 38) },
			maxDistance = 12,
		},
		spawns = {
			{ name = "ArenaSpawn", position = Vector3.new(0, 2, 0), size = Vector3.new(12, 1, 12), color = Color3.fromRGB(220, 220, 220), material = Enum.Material.SmoothPlastic, transparency = 0.7 },
		},
	},

	ResearchFacility = {
		name = "ResearchFacility",
		theme = "Abandoned Research Facility",
		lighting = {
			Ambient = Color3.fromRGB(88, 96, 108),
			OutdoorAmbient = Color3.fromRGB(72, 78, 88),
			Brightness = 2,
			ClockTime = 2.5,
			FogColor = Color3.fromRGB(92, 101, 113),
			FogStart = 80,
			FogEnd = 220,
		},
		rooms = {
			{
				name = "CentralHub",
				signText = "CENTRAL HUB",
				center = Vector3.new(0, 0, 0),
				size = Vector3.new(32, 1, 26),
				floorColor = Color3.fromRGB(112, 117, 124),
				openings = {
					east = { { offset = -4, width = 6, height = 9 } },
					west = { { offset = 4, width = 6, height = 9 } },
					north = { { offset = 2, width = 7, height = 9 }, { offset = -10, width = 5, height = 4, bottom = 2 } },
					south = { { offset = -2, width = 7, height = 9 }, { offset = 10, width = 4, height = 3, bottom = 1 } },
				},
			},
			{
				name = "ServerRoom",
				signText = "SERVER ROOM",
				center = Vector3.new(28, 0, -4),
				size = Vector3.new(24, 1, 18),
				floorColor = Color3.fromRGB(100, 107, 121),
				wallColor = Color3.fromRGB(70, 78, 90),
				openings = {
					west = { { offset = 0, width = 6, height = 9 } },
					north = { { offset = -7, width = 4, height = 3, bottom = 1 } },
					south = { { offset = 7, width = 5, height = 4, bottom = 2 } },
				},
			},
			{
				name = "StorageBay",
				signText = "STORAGE BAY",
				center = Vector3.new(-28, 0, 4),
				size = Vector3.new(24, 1, 20),
				floorColor = Color3.fromRGB(118, 112, 101),
				wallColor = Color3.fromRGB(86, 80, 72),
				openings = {
					east = { { offset = 0, width = 6, height = 9 } },
					north = { { offset = -7, width = 5, height = 4, bottom = 2 } },
					south = { { offset = 7, width = 4, height = 3, bottom = 1 } },
				},
			},
			{
				name = "Laboratory",
				signText = "BIO LAB",
				center = Vector3.new(2, 0, -21),
				size = Vector3.new(22, 1, 16),
				floorColor = Color3.fromRGB(103, 119, 106),
				wallColor = Color3.fromRGB(77, 93, 82),
				openings = {
					south = { { offset = 0, width = 7, height = 9 } },
					east = { { offset = 4, width = 5, height = 4, bottom = 2 } },
					west = { { offset = -4, width = 4, height = 3, bottom = 1 } },
				},
			},
			{
				name = "GeneratorRoom",
				signText = "GENERATOR ROOM",
				center = Vector3.new(-2, 0, 21),
				size = Vector3.new(22, 1, 16),
				floorColor = Color3.fromRGB(119, 102, 99),
				wallColor = Color3.fromRGB(90, 76, 74),
				openings = {
					north = { { offset = 0, width = 7, height = 9 } },
					east = { { offset = 4, width = 4, height = 3, bottom = 1 } },
					west = { { offset = -4, width = 5, height = 4, bottom = 2 } },
				},
			},
		},
		doors = {
			{ name = "Door_Hub_Server", label = "Blast Door", position = Vector3.new(16, 0, -4), axis = "Z", width = 6, holdDuration = 2, loaderText = "Cycling blast door" },
			{ name = "Door_Hub_Storage", label = "Bulkhead", position = Vector3.new(-16, 0, 4), axis = "Z", width = 6, holdDuration = 2, loaderText = "Cycling bulkhead" },
			{ name = "Door_Hub_Lab", label = "Lab Seal", position = Vector3.new(2, 0, -13), axis = "X", width = 7, holdDuration = 2, loaderText = "Unlocking lab seal" },
			{ name = "Door_Hub_Generator", label = "Power Door", position = Vector3.new(-2, 0, 13), axis = "X", width = 7, holdDuration = 2, loaderText = "Spinning up power door" },
		},
		windows = {
			{ name = "Window_Hub_North", position = Vector3.new(-10, 0, -13), width = 5, height = 4, bottom = 2, rotation = 0 },
			{ name = "Window_Server_South", position = Vector3.new(40, 0, 5), width = 5, height = 4, bottom = 2, rotation = 90 },
			{ name = "Window_Storage_North", position = Vector3.new(-40, 0, -6), width = 5, height = 4, bottom = 2, rotation = 90 },
			{ name = "Window_Lab_East", position = Vector3.new(13, 0, -17), width = 5, height = 4, bottom = 2, rotation = 90 },
			{ name = "Window_Generator_West", position = Vector3.new(-13, 0, 17), width = 5, height = 4, bottom = 2, rotation = 90 },
		},
		vents = {
			{ name = "Vent_Hub_South", position = Vector3.new(10, 0, 13), width = 4, height = 3, bottom = 1, rotation = 0 },
			{ name = "Vent_Server_North", position = Vector3.new(21, 0, -13), width = 4, height = 3, bottom = 1, rotation = 0 },
			{ name = "Vent_Storage_South", position = Vector3.new(-21, 0, 14), width = 4, height = 3, bottom = 1, rotation = 0 },
			{ name = "Vent_Lab_West", position = Vector3.new(-9, 0, -25), width = 4, height = 3, bottom = 1, rotation = 90 },
			{ name = "Vent_Generator_East", position = Vector3.new(9, 0, 25), width = 4, height = 3, bottom = 1, rotation = 90 },
		},
		catwalks = {
			{ name = "Catwalk_Server", position = Vector3.new(28, 7.5, -4), size = Vector3.new(12, 1, 5) },
			{ name = "Catwalk_Storage", position = Vector3.new(-28, 7.5, 4), size = Vector3.new(14, 1, 5) },
		},
		slipperyFloors = {
			{ name = "CryoSpill_Lab", position = Vector3.new(6, 0.1, -18), size = Vector3.new(7, 0.2, 7) },
			{ name = "CoolantLeak_Generator", position = Vector3.new(-7, 0.1, 23), size = Vector3.new(8, 0.2, 8) },
		},
		cover = {
			{ name = "Rack_Server_A", position = Vector3.new(22, 2.5, -8), size = Vector3.new(3, 5, 2), material = Enum.Material.Metal },
			{ name = "Rack_Server_B", position = Vector3.new(34, 2.5, -2), size = Vector3.new(3, 5, 2), material = Enum.Material.Metal },
			{ name = "Crate_Storage_A", position = Vector3.new(-34, 1.5, 1), size = Vector3.new(3, 3, 3), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(116, 84, 58) },
			{ name = "Crate_Storage_B", position = Vector3.new(-24, 1.5, 8), size = Vector3.new(4, 3, 4), material = Enum.Material.WoodPlanks, color = Color3.fromRGB(124, 91, 66) },
			{ name = "Counter_Lab", position = Vector3.new(-4, 1.5, -23), size = Vector3.new(6, 3, 2), material = Enum.Material.Metal },
			{ name = "Turbine_Generator", position = Vector3.new(2, 2.5, 23), size = Vector3.new(5, 5, 5), material = Enum.Material.Metal },
			{ name = "Hub_Console", position = Vector3.new(0, 1.5, -3), size = Vector3.new(5, 3, 2), material = Enum.Material.Metal },
		},
		tasks = {
			{ name = "Hack_ServerRack", type = "ComputerHack", label = "Server Rack", position = Vector3.new(33, 0, -8), holdDuration = 3, loaderText = "Injecting terminal exploit" },
			{ name = "Hack_BioTerminal", type = "ComputerHack", label = "Bio Terminal", position = Vector3.new(8, 0, -24), holdDuration = 3, loaderText = "Decrypting lab archives" },
			{ name = "Hack_PowerConsole", type = "ComputerHack", label = "Power Console", position = Vector3.new(-8, 0, 18), holdDuration = 3, loaderText = "Rerouting generator output" },
			{ name = "Valve_CoolantLoop", type = "ValveTurn", position = Vector3.new(3, 0, 25), turnsRequired = 3 },
			{ name = "Valve_StoragePressure", type = "ValveTurn", position = Vector3.new(-35, 0, -2), turnsRequired = 3 },
			{ name = "Panel_SecurityOverride", type = "PanelPuzzle", position = Vector3.new(10, 0, 6), sequence = { 1, 3, 2 } },
			{ name = "Panel_LabAirlock", type = "PanelPuzzle", position = Vector3.new(-7, 0, -18), sequence = { 2, 1, 3 } },
		},
		spawns = {
			{ name = "MainSpawn", position = Vector3.new(0, 2, 0), size = Vector3.new(10, 1, 10) },
		},
	},
}

local function getDefinitionsFolder()
	local folder = ServerStorage:FindFirstChild(DEFINITIONS_FOLDER_NAME)
	if not folder then
		return nil
	end

	return folder
end

local function findModuleByName(folder, name)
	if not folder then
		return nil
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local sanitizedName = child.Name:gsub("%.lua$", "")
			if child.Name == name or sanitizedName == name then
				return child
			end
		end
	end

	return nil
end

function Registry:GetMap(name)
	local fromBuiltin = BUILTIN_DEFINITIONS[name]
	if fromBuiltin then
		return fromBuiltin
	end

	local definitionsFolder = getDefinitionsFolder()
	local moduleScript = findModuleByName(definitionsFolder, name)
	if not moduleScript then
		return nil
	end

	return require(moduleScript)
end

function Registry:GetDefaultMapName()
	if self:GetMap(DEFAULT_MAP_NAME) then
		return DEFAULT_MAP_NAME
	end

	do
		local names = {}
		for name in pairs(BUILTIN_DEFINITIONS) do
			table.insert(names, name)
		end
		table.sort(names)
		if #names > 0 then
			return names[1]
		end
	end

	local definitionsFolder = getDefinitionsFolder()
	if not definitionsFolder then
		return nil
	end

	local firstModule = definitionsFolder:FindFirstChildWhichIsA("ModuleScript")
	if not firstModule then
		return nil
	end

	return firstModule.Name:gsub("%.lua$", "")
end

function Registry:ListMaps()
	local names = {}
	local seen = {}

	for name in pairs(BUILTIN_DEFINITIONS) do
		seen[name] = true
		table.insert(names, name)
	end

	local definitionsFolder = getDefinitionsFolder()
	if not definitionsFolder then
		table.sort(names)
		return names
	end

	for _, child in ipairs(definitionsFolder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local sanitizedName = child.Name:gsub("%.lua$", "")
			if not seen[sanitizedName] then
				seen[sanitizedName] = true
				table.insert(names, sanitizedName)
			end
		end
	end

	table.sort(names)
	return names
end

return Registry