-- services
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- variables
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize
local container = Instance.new("Folder", gethui and gethui() or game:GetService("CoreGui"))

-- locals
local floor = math.floor
local round = math.round
local sin = math.sin
local cos = math.cos
local clear = table.clear
local unpack = table.unpack
local find = table.find
local create = table.create
local fromMatrix = CFrame.fromMatrix

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)
local VERTICES = {
	Vector3.new(-1, -1, -1), Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1), Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1), Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1), Vector3.new(1, -1, 1)
}

-- helpers
local function isBodyPart(name)
	return name == "Head" or name:find("Torso") or name:find("Leg") or name:find("Arm")
end

local function getBoundingBox(parts)
	local min, max
	for i = 1, #parts do
		local part = parts[i]
		local cframe, size = part.CFrame, part.Size

		min = min3(min or cframe.Position, (cframe - size*0.5).Position)
		max = max3(max or cframe.Position, (cframe + size*0.5).Position)
	end

	local center = (min + max)*0.5
	local front = Vector3.new(center.X, center.Y, max.Z)
	return CFrame.new(center, front), max - min
end

local function worldToScreen(world)
	local screen, inBounds = camera:WorldToViewportPoint(world)
	return Vector2.new(screen.X, screen.Y), inBounds, screen.Z
end

local function calculateCorners(cframe, size)
	local corners = create(#VERTICES)
	for i = 1, #VERTICES do
		corners[i] = worldToScreen((cframe + size*0.5*VERTICES[i]).Position)
	end

	local min = Vector2.new(math.huge, math.huge)
	local max = Vector2.new(-math.huge, -math.huge)
	for i = 1, #corners do
		min = Vector2.new(math.min(min.X, corners[i].X), math.min(min.Y, corners[i].Y))
		max = Vector2.new(math.max(max.X, corners[i].X), math.max(max.Y, corners[i].Y))
	end
	return {
		corners = corners,
		topLeft = Vector2.new(floor(min.X), floor(min.Y)),
		topRight = Vector2.new(floor(max.X), floor(min.Y)),
		bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
		bottomRight = Vector2.new(floor(max.X), floor(max.Y))
	}
end

local function lerp2(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
	return Color3.new(
		c1.R + (c2.R - c1.R) * t,
		c1.G + (c2.G - c1.G) * t,
		c1.B + (c2.B - c1.B) * t
	)
end

-- ESP object
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(player, interface)
	local self = setmetatable({}, EspObject)
	self.player = player
	self.interface = interface
	self:Construct()
	return self
end

function EspObject:_create(class, properties)
	local drawing = Drawing.new(class)
	for property, value in next, properties do
		pcall(function() drawing[property] = value end)
	end
	self.bin[#self.bin + 1] = drawing
	return drawing
end

function EspObject:Construct()
	self.charCache = {}
	self.childCount = 0
	self.bin = {}
	self.drawings = {
		visible = {
			box = self:_create("Square", {Thickness = 1, Visible = false}),
			boxOutline = self:_create("Square", {Thickness = 3, Visible = false}),
			healthBar = self:_create("Line", {Thickness = 1, Visible = false}),
			healthBarOutline = self:_create("Line", {Thickness = 3, Visible = false}),
			healthText = self:_create("Text", {Center = true, Visible = false}),
			name = self:_create("Text", {Center = true, Visible = false})
		}
	}

	self.renderConnection = runService.Heartbeat:Connect(function()
		self:Update()
		self:Render()
	end)
end

function EspObject:Destruct()
	self.renderConnection:Disconnect()
	for i = 1, #self.bin do
		self.bin[i]:Remove()
	end
	clear(self)
end

function EspObject:Update()
	local interface = self.interface
	self.options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"]
	self.character = interface.getCharacter(self.player)
	self.health, self.maxHealth = interface.getHealth(self.player)
	self.enabled = self.options.enabled and self.character

	if not self.enabled then
		self.onScreen = false
		return
	end

	local head = self.character and self.character:FindFirstChild("Head")
	if not head then
		self.charCache = {}
		self.onScreen = false
		return
	end

	local _, onScreen, depth = worldToScreen(head.Position)
	self.onScreen = onScreen
	self.distance = depth

	local children = self.character:GetChildren()
	if not self.charCache[1] or self.childCount ~= #children then
		clear(self.charCache)
		for i = 1, #children do
			local part = children[i]
			if part:IsA("BasePart") and isBodyPart(part.Name) then
				self.charCache[#self.charCache+1] = part
			end
		end
		self.childCount = #children
	end

	self.corners = calculateCorners(getBoundingBox(self.charCache))
end

function EspObject:Render()
	if not self.enabled or not self.onScreen then
		for _, draw in pairs(self.drawings.visible) do
			draw.Visible = false
		end
		return
	end

	local visible = self.drawings.visible
	local corners = self.corners
	local options = self.options

	-- Box
	visible.box.Visible = options.box
	if visible.box.Visible then
		visible.box.Position = corners.topLeft
		visible.box.Size = corners.bottomRight - corners.topLeft
		visible.box.Color = options.boxColor[1]
		visible.box.Transparency = options.boxColor[2]

		visible.boxOutline.Visible = options.boxOutline
		if visible.boxOutline.Visible then
			visible.boxOutline.Position = corners.topLeft
			visible.boxOutline.Size = corners.bottomRight - corners.topLeft
			visible.boxOutline.Color = options.boxOutlineColor[1]
			visible.boxOutline.Transparency = options.boxOutlineColor[2]
		end
	end

	-- HealthBar
	visible.healthBar.Visible = options.healthBar
	if visible.healthBar.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

		visible.healthBar.From = lerp2(barTo, barFrom, self.health/self.maxHealth)
		visible.healthBar.To = barTo
		visible.healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, self.health/self.maxHealth)

		visible.healthBarOutline.Visible = options.healthBarOutline
		if visible.healthBarOutline.Visible then
			visible.healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
			visible.healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
			visible.healthBarOutline.Color = options.healthBarOutlineColor[1]
			visible.healthBarOutline.Transparency = options.healthBarOutlineColor[2]
		end
	end
end

-- ESP Interface
local EspInterface = {
	_objectCache = {},
	teamSettings = {
		enemy = {
			enabled = true,
			box = true,
			boxColor = {Color3.new(1,1,1),1},
			boxOutline = true,
			boxOutlineColor = {Color3.new(0,0,0),1},
			healthBar = true,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = {Color3.new(0,0,0),1}
		},
		friendly = {
			enabled = true,
			box = true,
			boxColor = {Color3.new(0,1,0),1},
			boxOutline = true,
			boxOutlineColor = {Color3.new(0,0,0),1},
			healthBar = true,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = {Color3.new(0,0,0),1}
		}
	}
}

function EspInterface.isFriendly(player)
	return player.Team and player.Team == localPlayer.Team
end

function EspInterface.getCharacter(player)
	return player.Character
end

function EspInterface.getHealth(player)
	local character = EspInterface.getCharacter(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth
	end
	return 100, 100
end

function EspInterface.AddPlayer(player)
	local obj = EspObject.new(player, EspInterface)
	EspInterface._objectCache[player] = obj
end

function EspInterface.RemovePlayer(player)
	local obj = EspInterface._objectCache[player]
	if obj then
		obj:Destruct()
		EspInterface._objectCache[player] = nil
	end
end

-- Connect players
for i, player in ipairs(players:GetPlayers()) do
	if player ~= localPlayer then
		EspInterface.AddPlayer(player)
	end
end

players.PlayerAdded:Connect(function(player)
	EspInterface.AddPlayer(player)
end)

players.PlayerRemoving:Connect(function(player)
	EspInterface.RemovePlayer(player)
end)

return EspInterface
