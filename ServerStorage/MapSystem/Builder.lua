local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Builder = {}
Builder.__index = Builder

local DEFAULT_WALL_HEIGHT = 12
local DEFAULT_WALL_THICKNESS = 1

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function applyProperties(instance, properties)
	for key, value in pairs(properties) do
		instance[key] = value
	end

	return instance
end

local function createPart(parent, name, size, cframe, properties)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	if properties then
		applyProperties(part, properties)
	end

	return part
end

local function createModel(parent, name)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function toRotationCFrame(rotation)
	if typeof(rotation) == "Vector3" then
		return CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	elseif type(rotation) == "number" then
		return CFrame.Angles(0, math.rad(rotation), 0)
	end

	return CFrame.new()
end

local function getPromptPositions(spec, axis, height)
	if spec.promptPositions then
		return spec.promptPositions
	end

	local offset = spec.promptOffset or math.max(4, (spec.width or 6) * 0.5)
	local promptHeight = spec.promptHeight or math.max(2, math.min(6, height * 0.5))

	if axis == "X" then
		return {
			spec.position + Vector3.new(0, promptHeight, -offset),
			spec.position + Vector3.new(0, promptHeight, offset),
		}
	end

	return {
		spec.position + Vector3.new(-offset, promptHeight, 0),
		spec.position + Vector3.new(offset, promptHeight, 0),
	}
end

local function openingSort(a, b)
	return a.offset < b.offset
end

local function createWallSegment(parent, name, side, roomCenter, roomSize, wallThickness, startOffset, endOffset, yBottom, segmentHeight, properties)
	if endOffset <= startOffset or segmentHeight <= 0 then
		return nil
	end

	local midpoint = (startOffset + endOffset) * 0.5
	local alongSize = endOffset - startOffset
	local yCenter = roomCenter.Y + yBottom + (segmentHeight * 0.5)

	if side == "north" then
		return createPart(parent, name, Vector3.new(alongSize, segmentHeight, wallThickness), CFrame.new(roomCenter.X + midpoint, yCenter, roomCenter.Z - (roomSize.Z * 0.5)), properties)
	elseif side == "south" then
		return createPart(parent, name, Vector3.new(alongSize, segmentHeight, wallThickness), CFrame.new(roomCenter.X + midpoint, yCenter, roomCenter.Z + (roomSize.Z * 0.5)), properties)
	elseif side == "east" then
		return createPart(parent, name, Vector3.new(wallThickness, segmentHeight, alongSize), CFrame.new(roomCenter.X + (roomSize.X * 0.5), yCenter, roomCenter.Z + midpoint), properties)
	end

	return createPart(parent, name, Vector3.new(wallThickness, segmentHeight, alongSize), CFrame.new(roomCenter.X - (roomSize.X * 0.5), yCenter, roomCenter.Z + midpoint), properties)
end

local function createWallWithOpenings(parent, side, roomSpec)
	local roomCenter = roomSpec.center
	local roomSize = roomSpec.size
	local wallHeight = roomSpec.wallHeight or DEFAULT_WALL_HEIGHT
	local wallThickness = roomSpec.wallThickness or DEFAULT_WALL_THICKNESS
	local wallColor = roomSpec.wallColor or Color3.fromRGB(81, 88, 96)
	local wallMaterial = roomSpec.wallMaterial or Enum.Material.Concrete
	local openings = {}

	for _, opening in ipairs((roomSpec.openings and roomSpec.openings[side]) or {}) do
		table.insert(openings, {
			offset = opening.offset,
			width = opening.width,
			height = opening.height,
			bottom = opening.bottom or 0,
		})
	end

	table.sort(openings, openingSort)

	local halfLength = ((side == "north" or side == "south") and roomSize.X or roomSize.Z) * 0.5
	local cursor = -halfLength
	local properties = {
		Material = wallMaterial,
		Color = wallColor,
		CanCollide = true,
	}

	for index, opening in ipairs(openings) do
		local openingLeft = math.max(-halfLength, opening.offset - (opening.width * 0.5))
		local openingRight = math.min(halfLength, opening.offset + (opening.width * 0.5))

		createWallSegment(parent, side .. "_solid_" .. index, side, roomCenter, roomSize, wallThickness, cursor, openingLeft, 0, wallHeight, properties)

		if opening.bottom > 0 then
			createWallSegment(parent, side .. "_lower_" .. index, side, roomCenter, roomSize, wallThickness, openingLeft, openingRight, 0, opening.bottom, properties)
		end

		local topStart = opening.bottom + opening.height
		if topStart < wallHeight then
			createWallSegment(parent, side .. "_upper_" .. index, side, roomCenter, roomSize, wallThickness, openingLeft, openingRight, topStart, wallHeight - topStart, properties)
		end

		cursor = openingRight
	end

	createWallSegment(parent, side .. "_solid_final", side, roomCenter, roomSize, wallThickness, cursor, halfLength, 0, wallHeight, properties)
end

function Builder.new(rootModel)
	local self = setmetatable({}, Builder)
	self.rootModel = rootModel
	self.geometryFolder = ensureFolder(rootModel, "Geometry")
	self.propsFolder = ensureFolder(rootModel, "Props")
	self.taskFolder = ensureFolder(rootModel, "Tasks")
	self.spawnFolder = ensureFolder(rootModel, "Spawns")
	self.taskState = {
		total = 0,
		completed = 0,
		entries = {},
	}
	self.exitControllers = {}
	self.rootModel:SetAttribute("CompletedTaskCount", 0)
	self.rootModel:SetAttribute("RemainingTaskCount", 0)
	self.rootModel:SetAttribute("ExitUnlocked", false)
	return self
end

function Builder:ApplyLighting(lightingSpec)
	if not lightingSpec then
		return
	end

	for property, value in pairs(lightingSpec) do
		Lighting[property] = value
	end
end

function Builder:_refreshTaskState()
	self.rootModel:SetAttribute("TaskCount", self.taskState.total)
	self.rootModel:SetAttribute("CompletedTaskCount", self.taskState.completed)
	self.rootModel:SetAttribute("RemainingTaskCount", math.max(0, self.taskState.total - self.taskState.completed))
	self.rootModel:SetAttribute("ExitUnlocked", self.taskState.total == 0 or self.taskState.completed >= self.taskState.total)
end

function Builder:_registerTaskModel(model)
	self.taskState.total = self.taskState.total + 1
	self.taskState.entries[model] = false
	self:_refreshTaskState()
end

function Builder:_markTaskComplete(model)
	if self.taskState.entries[model] == nil or self.taskState.entries[model] == true then
		return
	end

	self.taskState.entries[model] = true
	self.taskState.completed = self.taskState.completed + 1
	self:_refreshTaskState()
	self:_updateExitControllers()
end

function Builder:_updateExitControllers()
	local unlocked = self.taskState.total == 0 or self.taskState.completed >= self.taskState.total
	self.rootModel:SetAttribute("ExitUnlocked", unlocked)

	for _, controller in ipairs(self.exitControllers) do
		controller.unlocked = unlocked
		controller.light.Color = unlocked and controller.unlockedColor or controller.lockedColor

		for _, prompt in ipairs(controller.prompts) do
			prompt.Enabled = unlocked and not controller.open and not controller.busy
		end
	end
end

function Builder:CreateRoom(roomSpec)
	local roomModel = createModel(self.geometryFolder, roomSpec.name)
	local floorThickness = roomSpec.floorThickness or 1
	local roomSize = roomSpec.size
	local roomCenter = roomSpec.center
	local wallHeight = roomSpec.wallHeight or DEFAULT_WALL_HEIGHT

	createPart(roomModel, "Floor", Vector3.new(roomSize.X, floorThickness, roomSize.Z), CFrame.new(roomCenter.X, roomCenter.Y - (floorThickness * 0.5), roomCenter.Z), {
		Material = roomSpec.floorMaterial or Enum.Material.Concrete,
		Color = roomSpec.floorColor or Color3.fromRGB(116, 120, 125),
		CanCollide = true,
	})

	createPart(roomModel, "Ceiling", Vector3.new(roomSize.X, 1, roomSize.Z), CFrame.new(roomCenter.X, roomCenter.Y + wallHeight + 0.5, roomCenter.Z), {
		Material = roomSpec.ceilingMaterial or Enum.Material.Metal,
		Color = roomSpec.ceilingColor or Color3.fromRGB(67, 73, 80),
		CanCollide = true,
	})

	for _, side in ipairs({ "north", "south", "east", "west" }) do
		createWallWithOpenings(roomModel, side, roomSpec)
	end

	if roomSpec.signText then
		local sign = createPart(roomModel, "Sign", Vector3.new(6, 2, 0.2), CFrame.new(roomCenter.X, roomCenter.Y + wallHeight - 1.5, roomCenter.Z), {
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 44, 51),
			CanCollide = false,
		})

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(220, 60)
		billboard.StudsOffset = Vector3.new(0, 0, 0.2)
		billboard.AlwaysOnTop = true
		billboard.Parent = sign

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = roomSpec.signText
		label.TextColor3 = Color3.fromRGB(233, 238, 242)
		label.TextStrokeTransparency = 0.75
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = billboard
	end
end

function Builder:CreateDoor(doorSpec)
	local doorModel = createModel(self.propsFolder, doorSpec.name)
	local axis = doorSpec.axis or "X"
	local width = doorSpec.width or 6
	local height = doorSpec.height or 9
	local thickness = doorSpec.thickness or 0.6
	local closedCenter = doorSpec.position + Vector3.new(0, height * 0.5, 0)
	local closedCFrame
	local openCFrame
	local panelSize

	if axis == "X" then
		panelSize = Vector3.new(width, height, thickness)
		closedCFrame = CFrame.new(closedCenter)
		openCFrame = closedCFrame * CFrame.new(doorSpec.slideDistance or (width + 0.5), 0, 0)
	else
		panelSize = Vector3.new(thickness, height, width)
		closedCFrame = CFrame.new(closedCenter)
		openCFrame = closedCFrame * CFrame.new(0, 0, doorSpec.slideDistance or (width + 0.5))
	end

	local panel = createPart(doorModel, "DoorPanel", panelSize, closedCFrame, {
		Material = Enum.Material.DiamondPlate,
		Color = doorSpec.color or Color3.fromRGB(148, 154, 165),
		CanCollide = true,
	})

	local prompts = {}
	for index, promptPosition in ipairs(getPromptPositions(doorSpec, axis, height)) do
		local promptAnchor = createPart(doorModel, "PromptAnchor" .. index, Vector3.new(2, 2, 2), CFrame.new(promptPosition), {
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = doorSpec.label or "Bulkhead"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = doorSpec.maxDistance or 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptAnchor
		table.insert(prompts, prompt)
	end

	local isOpen = false
	local busy = false

	local function syncPrompts()
		for _, prompt in ipairs(prompts) do
			if isOpen then
				prompt.ActionText = doorSpec.closeActionText or "Slam Shut"
				prompt.HoldDuration = doorSpec.closeHoldDuration or 0
				prompt:SetAttribute("UseLoadingGui", prompt.HoldDuration > 0)
				prompt:SetAttribute("LoaderText", doorSpec.closeLoaderText or "Slamming shut")
			else
				prompt.ActionText = doorSpec.openActionText or "Open"
				prompt.HoldDuration = doorSpec.holdDuration or 3
				prompt:SetAttribute("UseLoadingGui", prompt.HoldDuration > 0)
				prompt:SetAttribute("LoaderText", doorSpec.loaderText or "Cycling door")
			end
			prompt.Enabled = not busy
		end
	end

	local function tweenDoor(targetCFrame, tweenTime, easingStyle, easingDirection)
		local tween = TweenService:Create(panel, TweenInfo.new(tweenTime, easingStyle, easingDirection), { CFrame = targetCFrame })
		tween:Play()
		tween.Completed:Wait()
	end

	local function openDoor()
		busy = true
		syncPrompts()
		panel.CanCollide = false
		tweenDoor(openCFrame, doorSpec.openTweenTime or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		isOpen = true
		busy = false
		syncPrompts()
	end

	local function closeDoor()
		busy = true
		syncPrompts()
		panel.CanCollide = true
		tweenDoor(closedCFrame, doorSpec.slamCloseTime or 0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		isOpen = false
		busy = false
		syncPrompts()
	end

	for _, prompt in ipairs(prompts) do
		prompt.Triggered:Connect(function()
			if busy then
				return
			end

			if isOpen then
				closeDoor()
			else
				openDoor()
			end
		end)
	end

	syncPrompts()
end

function Builder:CreateWindow(windowSpec)
	local frameModel = createModel(self.propsFolder, windowSpec.name)
	local width = windowSpec.width or 5
	local height = windowSpec.height or 4
	local thickness = windowSpec.thickness or 0.35
	local border = windowSpec.borderThickness or 0.35
	local center = windowSpec.position + Vector3.new(0, windowSpec.bottom + (height * 0.5), 0)
	local rotation = CFrame.Angles(0, math.rad(windowSpec.rotation or 0), 0)
	local base = CFrame.new(center) * rotation

	createPart(frameModel, "Top", Vector3.new(width + border, border, thickness), base * CFrame.new(0, (height * 0.5) + (border * 0.5), 0), { Material = Enum.Material.Metal, Color = windowSpec.color or Color3.fromRGB(122, 129, 139), CanCollide = true })
	createPart(frameModel, "Bottom", Vector3.new(width + border, border, thickness), base * CFrame.new(0, -(height * 0.5) - (border * 0.5), 0), { Material = Enum.Material.Metal, Color = windowSpec.color or Color3.fromRGB(122, 129, 139), CanCollide = true })
	createPart(frameModel, "Left", Vector3.new(border, height, thickness), base * CFrame.new(-(width * 0.5) - (border * 0.5), 0, 0), { Material = Enum.Material.Metal, Color = windowSpec.color or Color3.fromRGB(122, 129, 139), CanCollide = true })
	createPart(frameModel, "Right", Vector3.new(border, height, thickness), base * CFrame.new((width * 0.5) + (border * 0.5), 0, 0), { Material = Enum.Material.Metal, Color = windowSpec.color or Color3.fromRGB(122, 129, 139), CanCollide = true })
	createPart(frameModel, "BrokenGlass", Vector3.new(width, height, 0.08), base, { Material = Enum.Material.Glass, Color = Color3.fromRGB(182, 218, 237), Transparency = 0.82, CanCollide = false })
end

function Builder:CreateVent(ventSpec)
	local frameModel = createModel(self.propsFolder, ventSpec.name)
	local width = ventSpec.width or 4
	local height = ventSpec.height or 3
	local thickness = ventSpec.thickness or 0.35
	local border = ventSpec.borderThickness or 0.3
	local center = ventSpec.position + Vector3.new(0, ventSpec.bottom + (height * 0.5), 0)
	local rotation = CFrame.Angles(0, math.rad(ventSpec.rotation or 0), 0)
	local base = CFrame.new(center) * rotation

	createPart(frameModel, "Top", Vector3.new(width + border, border, thickness), base * CFrame.new(0, (height * 0.5) + (border * 0.5), 0), { Material = Enum.Material.Metal, Color = Color3.fromRGB(74, 79, 86), CanCollide = true })
	createPart(frameModel, "Bottom", Vector3.new(width + border, border, thickness), base * CFrame.new(0, -(height * 0.5) - (border * 0.5), 0), { Material = Enum.Material.Metal, Color = Color3.fromRGB(74, 79, 86), CanCollide = true })
	createPart(frameModel, "Left", Vector3.new(border, height, thickness), base * CFrame.new(-(width * 0.5) - (border * 0.5), 0, 0), { Material = Enum.Material.Metal, Color = Color3.fromRGB(74, 79, 86), CanCollide = true })
	createPart(frameModel, "Right", Vector3.new(border, height, thickness), base * CFrame.new((width * 0.5) + (border * 0.5), 0, 0), { Material = Enum.Material.Metal, Color = Color3.fromRGB(74, 79, 86), CanCollide = true })
end

function Builder:CreateCatwalk(catwalkSpec)
	local model = createModel(self.propsFolder, catwalkSpec.name)
	local size = catwalkSpec.size
	local base = createPart(model, "Deck", size, CFrame.new(catwalkSpec.position), { Material = Enum.Material.DiamondPlate, Color = catwalkSpec.color or Color3.fromRGB(101, 108, 118), CanCollide = true })
	local railHeight = catwalkSpec.railHeight or 2.5
	local railThickness = 0.25
	createPart(model, "RailLeft", Vector3.new(size.X, railHeight, railThickness), base.CFrame * CFrame.new(0, (railHeight * 0.5) + (size.Y * 0.5), -(size.Z * 0.5) + (railThickness * 0.5)), { Material = Enum.Material.Metal, Color = Color3.fromRGB(82, 88, 96), CanCollide = true })
	createPart(model, "RailRight", Vector3.new(size.X, railHeight, railThickness), base.CFrame * CFrame.new(0, (railHeight * 0.5) + (size.Y * 0.5), (size.Z * 0.5) - (railThickness * 0.5)), { Material = Enum.Material.Metal, Color = Color3.fromRGB(82, 88, 96), CanCollide = true })
end

function Builder:CreateScaffoldTower(scaffoldSpec)
	local model = createModel(self.propsFolder, scaffoldSpec.name)
	local size = scaffoldSpec.size
	local center = scaffoldSpec.position + Vector3.new(0, size.Y * 0.5, 0)
	local postThickness = scaffoldSpec.postThickness or 1.2
	local deckThickness = scaffoldSpec.deckThickness or 0.8
	local postColor = scaffoldSpec.postColor or Color3.fromRGB(201, 201, 201)
	local deckColor = scaffoldSpec.deckColor or Color3.fromRGB(240, 240, 240)

	local postOffsets = {
		Vector3.new(-(size.X * 0.5) + (postThickness * 0.5), 0, -(size.Z * 0.5) + (postThickness * 0.5)),
		Vector3.new((size.X * 0.5) - (postThickness * 0.5), 0, -(size.Z * 0.5) + (postThickness * 0.5)),
		Vector3.new(-(size.X * 0.5) + (postThickness * 0.5), 0, (size.Z * 0.5) - (postThickness * 0.5)),
		Vector3.new((size.X * 0.5) - (postThickness * 0.5), 0, (size.Z * 0.5) - (postThickness * 0.5)),
	}

	for index, offset in ipairs(postOffsets) do
		createPart(model, "Post" .. index, Vector3.new(postThickness, size.Y, postThickness), CFrame.new(center + offset), {
			Material = Enum.Material.Metal,
			Color = postColor,
			CanCollide = true,
		})
	end

	for index, deckLevel in ipairs(scaffoldSpec.deckLevels or {}) do
		createPart(model, "Deck" .. index, Vector3.new(size.X - 1, deckThickness, size.Z - 1), CFrame.new(scaffoldSpec.position + Vector3.new(0, deckLevel, 0)), {
			Material = Enum.Material.DiamondPlate,
			Color = deckColor,
			CanCollide = true,
		})
	end

	createPart(model, "BraceNorth", Vector3.new(size.X - 1, postThickness, postThickness), CFrame.new(scaffoldSpec.position + Vector3.new(0, size.Y * 0.66, -(size.Z * 0.5) + 0.5)), {
		Material = Enum.Material.Metal,
		Color = postColor,
		CanCollide = true,
	})
	createPart(model, "BraceSouth", Vector3.new(size.X - 1, postThickness, postThickness), CFrame.new(scaffoldSpec.position + Vector3.new(0, size.Y * 0.33, (size.Z * 0.5) - 0.5)), {
		Material = Enum.Material.Metal,
		Color = postColor,
		CanCollide = true,
	})
end

function Builder:CreateSlipperyFloor(floorSpec)
	createPart(self.propsFolder, floorSpec.name, floorSpec.size, CFrame.new(floorSpec.position), {
		Material = Enum.Material.Ice,
		Color = floorSpec.color or Color3.fromRGB(168, 211, 230),
		Transparency = floorSpec.transparency or 0.1,
		CanCollide = true,
		CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0.2, 1, 1),
	})
end

function Builder:CreateCover(coverSpec)
	local cframe = coverSpec.cframe or (CFrame.new(coverSpec.position) * toRotationCFrame(coverSpec.rotation))
	createPart(self.propsFolder, coverSpec.name, coverSpec.size, cframe, {
		Material = coverSpec.material or Enum.Material.Metal,
		Color = coverSpec.color or Color3.fromRGB(104, 111, 118),
		Transparency = coverSpec.transparency or 0,
		CanCollide = true,
	})
end

function Builder:CreateCrawlBlocker(crawlSpec)
	createPart(self.propsFolder, crawlSpec.name, crawlSpec.size, CFrame.new(crawlSpec.position), {
		Material = crawlSpec.material or Enum.Material.ForceField,
		Color = crawlSpec.color or Color3.fromRGB(90, 170, 255),
		Transparency = crawlSpec.transparency == nil and 1 or crawlSpec.transparency,
		CanCollide = true,
		CanTouch = false,
		CanQuery = crawlSpec.transparency ~= 1,
		CollisionGroup = crawlSpec.collisionGroup or "CrawlBlocker",
	})
end

function Builder:CreateComputerTask(taskSpec)
	local model = createModel(self.taskFolder, taskSpec.name)
	self:_registerTaskModel(model)
	local basePosition = taskSpec.position
	createPart(model, "Desk", Vector3.new(3, 1.5, 1.5), CFrame.new(basePosition + Vector3.new(0, 0.75, 0)), { Material = Enum.Material.Metal, Color = Color3.fromRGB(72, 77, 84), CanCollide = true })
	local monitor = createPart(model, "Monitor", Vector3.new(2.3, 1.6, 0.2), CFrame.new(basePosition + Vector3.new(0, 2, -0.45)) * CFrame.Angles(math.rad(-10), 0, 0), { Material = Enum.Material.Neon, Color = Color3.fromRGB(24, 205, 170), CanCollide = false })
	createPart(model, "Keyboard", Vector3.new(1.8, 0.2, 0.7), CFrame.new(basePosition + Vector3.new(0, 1.55, 0.3)), { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(33, 36, 41), CanCollide = false })

	local promptAnchor = createPart(model, "PromptAnchor", Vector3.new(2, 2, 2), CFrame.new(basePosition + Vector3.new(0, 2, 1.5)), { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hack"
	prompt.ObjectText = taskSpec.label or "Terminal"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = taskSpec.holdDuration or 3
	prompt.MaxActivationDistance = taskSpec.maxDistance or 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor
	prompt:SetAttribute("UseLoadingGui", true)
	prompt:SetAttribute("LoaderText", taskSpec.loaderText or "Bypassing security")

	local completed = false
	prompt.Triggered:Connect(function()
		if completed then
			return
		end

		completed = true
		prompt.Enabled = false
		monitor.Color = Color3.fromRGB(74, 219, 89)
		monitor.Material = Enum.Material.Neon
		self:_markTaskComplete(model)
	end)
end

function Builder:CreateGeneratorTask(taskSpec)
	local model = createModel(self.taskFolder, taskSpec.name)
	self:_registerTaskModel(model)
	local basePosition = taskSpec.position
	createPart(model, "Housing", Vector3.new(6, 6, 4), CFrame.new(basePosition + Vector3.new(0, 3, 0)), {
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(180, 180, 180),
		CanCollide = true,
	})
	local panel = createPart(model, "HackPanel", Vector3.new(2.5, 2.5, 0.3), CFrame.new(basePosition + Vector3.new(0, 3.5, 2.15)), {
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 170, 60),
		CanCollide = false,
	})
	local light = createPart(model, "StatusLight", Vector3.new(1, 1, 1), CFrame.new(basePosition + Vector3.new(0, 6.5, 0)), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 90, 90),
		CanCollide = false,
	})

	local promptAnchor = createPart(model, "PromptAnchor", Vector3.new(2, 2, 2), CFrame.new(basePosition + Vector3.new(0, 3.5, 3.5)), {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hack"
	prompt.ObjectText = taskSpec.label or "Generator"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = taskSpec.holdDuration or 3
	prompt.MaxActivationDistance = taskSpec.maxDistance or 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor
	prompt:SetAttribute("UseLoadingGui", true)
	prompt:SetAttribute("LoaderText", taskSpec.loaderText or "Priming generator")

	local completed = false
	prompt.Triggered:Connect(function()
		if completed then
			return
		end

		completed = true
		prompt.Enabled = false
		panel.Color = Color3.fromRGB(82, 206, 103)
		light.Color = Color3.fromRGB(82, 206, 103)
		self:_markTaskComplete(model)
	end)
end

function Builder:CreateValveTask(taskSpec)
	local model = createModel(self.taskFolder, taskSpec.name)
	self:_registerTaskModel(model)
	local rootPosition = taskSpec.position
	local requiredTurns = taskSpec.turnsRequired or 3
	createPart(model, "Pipe", Vector3.new(1, 4, 1), CFrame.new(rootPosition + Vector3.new(0, 2, 0)), { Material = Enum.Material.Metal, Color = Color3.fromRGB(96, 102, 108), CanCollide = true })
	local wheel = createPart(model, "Wheel", Vector3.new(2.2, 0.35, 2.2), CFrame.new(rootPosition + Vector3.new(0, 2, 1.15)) * CFrame.Angles(math.rad(90), 0, 0), { Material = Enum.Material.Metal, Color = Color3.fromRGB(173, 88, 73), CanCollide = true })
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = taskSpec.maxDistance or 12
	clickDetector.Parent = wheel

	local turns = 0
	clickDetector.MouseClick:Connect(function()
		if turns >= requiredTurns then
			return
		end

		turns = turns + 1
		wheel.CFrame = wheel.CFrame * CFrame.Angles(0, 0, math.rad(120))
		model:SetAttribute("Turns", turns)

		if turns >= requiredTurns then
			wheel.Color = Color3.fromRGB(82, 206, 103)
			self:_markTaskComplete(model)
		end
	end)
end

function Builder:CreatePanelTask(taskSpec)
	local model = createModel(self.taskFolder, taskSpec.name)
	self:_registerTaskModel(model)
	local position = taskSpec.position
	local sequence = taskSpec.sequence or { 1, 2, 3 }
	createPart(model, "Backing", Vector3.new(4.5, 5, 0.4), CFrame.new(position + Vector3.new(0, 2.5, 0)), { Material = Enum.Material.Metal, Color = Color3.fromRGB(61, 67, 74), CanCollide = true })
	local display = createPart(model, "Display", Vector3.new(3.2, 0.8, 0.25), CFrame.new(position + Vector3.new(0, 4.25, 0.25)), { Material = Enum.Material.Neon, Color = Color3.fromRGB(198, 157, 63), CanCollide = false })

	local buttonOffsets = { Vector3.new(-1.15, 2.8, 0.25), Vector3.new(0, 2.1, 0.25), Vector3.new(1.15, 2.8, 0.25) }
	local buttonColors = { Color3.fromRGB(214, 77, 77), Color3.fromRGB(89, 179, 219), Color3.fromRGB(91, 201, 119) }
	local progress = 0
	local completed = false

	local function resetPanel()
		progress = 0
		display.Color = Color3.fromRGB(198, 157, 63)
	end

	for index = 1, 3 do
		local button = createPart(model, "Button" .. index, Vector3.new(0.9, 0.9, 0.35), CFrame.new(position + buttonOffsets[index]), { Material = Enum.Material.Neon, Color = buttonColors[index], CanCollide = false })
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = taskSpec.maxDistance or 12
		clickDetector.Parent = button

		clickDetector.MouseClick:Connect(function()
			if completed then
				return
			end

			local expected = sequence[progress + 1]
			if index ~= expected then
				display.Color = Color3.fromRGB(232, 84, 84)
				task.delay(0.35, function()
					if not completed then
						resetPanel()
					end
				end)
				return
			end

			progress = progress + 1
			display.Color = Color3.fromRGB(89, 179, 219)

			if progress >= #sequence then
				completed = true
				display.Color = Color3.fromRGB(82, 206, 103)
				self:_markTaskComplete(model)
			end
		end)
	end
end

function Builder:CreateExitDoor(exitSpec)
	local model = createModel(self.propsFolder, exitSpec.name)
	local axis = exitSpec.axis or "Z"
	local width = exitSpec.width or 14
	local height = exitSpec.height or 14
	local thickness = exitSpec.thickness or 1.2
	local closedCenter = exitSpec.position + Vector3.new(0, height * 0.5, 0)
	local closedCFrame
	local openCFrame
	local panelSize

	if axis == "X" then
		panelSize = Vector3.new(width, height, thickness)
		closedCFrame = CFrame.new(closedCenter)
		openCFrame = closedCFrame * CFrame.new(exitSpec.slideDistance or (width + 1), 0, 0)
	else
		panelSize = Vector3.new(thickness, height, width)
		closedCFrame = CFrame.new(closedCenter)
		openCFrame = closedCFrame * CFrame.new(0, 0, exitSpec.slideDistance or (width + 1))
	end

	local panel = createPart(model, "DoorPanel", panelSize, closedCFrame, {
		Material = Enum.Material.DiamondPlate,
		Color = exitSpec.color or Color3.fromRGB(150, 150, 150),
		CanCollide = true,
		Reflectance = 0.05,
	})

	local light = createPart(model, "StatusLight", Vector3.new(2.2, 2.2, 2.2), CFrame.new(exitSpec.lightPosition or (exitSpec.position + Vector3.new(0, height + 3, 0))), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(230, 70, 70),
		CanCollide = false,
	})

	local prompts = {}
	for index, promptPosition in ipairs(getPromptPositions(exitSpec, axis, height)) do
		local promptAnchor = createPart(model, "PromptAnchor" .. index, Vector3.new(2, 2, 2), CFrame.new(promptPosition), {
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = exitSpec.actionText or "Escape"
		prompt.ObjectText = exitSpec.label or "Exit Door"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = exitSpec.holdDuration or 10
		prompt.MaxActivationDistance = exitSpec.maxDistance or 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = promptAnchor
		prompt:SetAttribute("UseLoadingGui", true)
		prompt:SetAttribute("LoaderText", exitSpec.loaderText or "Releasing exit lock")
		table.insert(prompts, prompt)
	end

	local escapeZone = createPart(model, "EscapeZone", exitSpec.escapeZoneSize or Vector3.new(10, 8, width), CFrame.new(exitSpec.escapeZonePosition or (exitSpec.position + Vector3.new(8, 4, 0))), {
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		CanQuery = false,
	})

	local controller = {
		prompts = prompts,
		light = light,
		lockedColor = exitSpec.lockedLightColor or Color3.fromRGB(230, 70, 70),
		unlockedColor = exitSpec.unlockedLightColor or Color3.fromRGB(80, 220, 120),
		open = false,
		busy = false,
		unlocked = false,
	}
	table.insert(self.exitControllers, controller)

	escapeZone.Touched:Connect(function(hit)
		if not controller.open then
			return
		end

		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local player = game:GetService("Players"):GetPlayerFromCharacter(character)
		if not player then
			return
		end

		player:SetAttribute("Escaped", true)
	end)

	for _, prompt in ipairs(prompts) do
		prompt.Triggered:Connect(function()
			if controller.busy or controller.open or not controller.unlocked then
				return
			end

			controller.busy = true
			for _, otherPrompt in ipairs(prompts) do
				otherPrompt.Enabled = false
			end

			panel.CanCollide = false
			local openTween = TweenService:Create(panel, TweenInfo.new(exitSpec.openTweenTime or 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { CFrame = openCFrame })
			openTween:Play()
			openTween.Completed:Wait()
			controller.open = true
			controller.busy = false
		end)
	end

	self:_updateExitControllers()
end

function Builder:CreateSpawn(spawnSpec)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = spawnSpec.name or "Spawn"
	spawn.Size = spawnSpec.size or Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(spawnSpec.position)
	spawn.Anchored = true
	spawn.Transparency = spawnSpec.transparency or 0.2
	spawn.Neutral = true
	spawn.Material = spawnSpec.material or Enum.Material.Neon
	spawn.Color = spawnSpec.color or Color3.fromRGB(87, 218, 135)
	spawn.Parent = self.spawnFolder
	return spawn
end

function Builder:BuildMap(mapDefinition)
	for _, room in ipairs(mapDefinition.rooms or {}) do
		self:CreateRoom(room)
	end

	for _, scaffold in ipairs(mapDefinition.scaffolds or {}) do
		self:CreateScaffoldTower(scaffold)
	end

	for _, door in ipairs(mapDefinition.doors or {}) do
		self:CreateDoor(door)
	end

	for _, window in ipairs(mapDefinition.windows or {}) do
		self:CreateWindow(window)
	end

	for _, vent in ipairs(mapDefinition.vents or {}) do
		self:CreateVent(vent)
	end

	for _, catwalk in ipairs(mapDefinition.catwalks or {}) do
		self:CreateCatwalk(catwalk)
	end

	for _, floorPatch in ipairs(mapDefinition.slipperyFloors or {}) do
		self:CreateSlipperyFloor(floorPatch)
	end

	for _, cover in ipairs(mapDefinition.cover or {}) do
		self:CreateCover(cover)
	end

	for _, crawlBlocker in ipairs(mapDefinition.crawlBlockers or {}) do
		self:CreateCrawlBlocker(crawlBlocker)
	end

	for _, taskSpec in ipairs(mapDefinition.tasks or {}) do
		if taskSpec.type == "ComputerHack" then
			self:CreateComputerTask(taskSpec)
		elseif taskSpec.type == "GeneratorHack" then
			self:CreateGeneratorTask(taskSpec)
		elseif taskSpec.type == "ValveTurn" then
			self:CreateValveTask(taskSpec)
		elseif taskSpec.type == "PanelPuzzle" then
			self:CreatePanelTask(taskSpec)
		end
	end

	if mapDefinition.exitDoor then
		self:CreateExitDoor(mapDefinition.exitDoor)
	end

	for _, spawn in ipairs(mapDefinition.spawns or {}) do
		self:CreateSpawn(spawn)
	end

	self.rootModel:SetAttribute("MapName", mapDefinition.name)
	self.rootModel:SetAttribute("MapTheme", mapDefinition.theme or "Facility")
	self:_refreshTaskState()
	self:_updateExitControllers()
	return self.rootModel
end

return Builder