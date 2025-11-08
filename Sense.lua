-- services
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

-- variables
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize
local container = Instance.new("Folder",
    gethui and gethui() or game:GetService("CoreGui"))

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

-- methods
local wtvp = camera.WorldToViewportPoint
local isA = workspace.IsA
local getPivot = workspace.GetPivot
local findFirstChild = workspace.FindFirstChild
local findFirstChildOfClass = workspace.FindFirstChildOfClass
local getChildren = workspace.GetChildren
local toOrientation = CFrame.identity.ToOrientation
local pointToObjectSpace = CFrame.identity.PointToObjectSpace
local lerpColor = Color3.new().Lerp
local min2 = Vector2.zero.Min
local max2 = Vector2.zero.Max
local lerp2 = Vector2.zero.Lerp
local min3 = Vector3.zero.Min
local max3 = Vector3.zero.Max

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0)
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0)
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1)
local NAME_OFFSET = Vector2.new(0, 2)
local DISTANCE_OFFSET = Vector2.new(0, 2)
local VERTICES = {
    Vector3.new(-1, -1, -1),
    Vector3.new(-1, 1, -1),
    Vector3.new(-1, 1, 1),
    Vector3.new(-1, -1, 1),
    Vector3.new(1, -1, -1),
    Vector3.new(1, 1, -1),
    Vector3.new(1, 1, 1),
    Vector3.new(1, -1, 1)
}

-- functions
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
    local screen, inBounds = wtvp(camera, world)
    return Vector2.new(screen.X, screen.Y), inBounds, screen.Z
end

local function calculateCorners(cframe, size)
    local corners = create(#VERTICES)
    for i = 1, #VERTICES do
        corners[i] = worldToScreen((cframe + size*0.5*VERTICES[i]).Position)
    end
    local min = min2(viewportSize, unpack(corners))
    local max = max2(Vector2.zero, unpack(corners))
    return {
        corners = corners,
        topLeft = Vector2.new(floor(min.X), floor(min.Y)),
        topRight = Vector2.new(floor(max.X), floor(min.Y)),
        bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
        bottomRight = Vector2.new(floor(max.X), floor(max.Y))
    }
end

local function rotateVector(vector, radians)
    local x, y = vector.X, vector.Y
    local c, s = cos(radians), sin(radians)
    return Vector2.new(x*c - y*s, x*s + y*c)
end

local function parseColor(self, color, isOutline)
    if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
        return self.interface.getTeamColor(self.player) or Color3.new(1,1,1)
    end
    return color
end

-- ESP Object
local EspObject = {}
EspObject.__index = EspObject

function EspObject.new(player, interface)
    local self = setmetatable({}, EspObject)
    self.player = assert(player, "Missing argument #1 (Player expected)")
    self.interface = assert(interface, "Missing argument #2 (table expected)")
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
        box3d = {
            {
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false })
            },
            {
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false })
            },
            {
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false })
            },
            {
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false }),
                self:_create("Line", { Thickness = 1, Visible = false })
            }
        },
        visible = {
            tracerOutline = self:_create("Line", { Thickness = 3, Visible = false }),
            tracer = self:_create("Line", { Thickness = 1, Visible = false }),
            boxFill = self:_create("Square", { Filled = true, Visible = false }),
            boxOutline = self:_create("Square", { Thickness = 3, Visible = false }),
            box = self:_create("Square", { Thickness = 1, Visible = false }),
            healthBarOutline = self:_create("Line", { Thickness = 3, Visible = false }),
            healthBar = self:_create("Line", { Thickness = 1, Visible = false }),
            healthText = self:_create("Text", { Center = true, Visible = false }),
            name = self:_create("Text", { Text = self.player.DisplayName, Center = true, Visible = false }),
            distance = self:_create("Text", { Center = true, Visible = false }),
            weapon = self:_create("Text", { Center = true, Visible = false }),
        },
        hidden = {
            arrowOutline = self:_create("Triangle", { Thickness = 3, Visible = false }),
            arrow = self:_create("Triangle", { Filled = true, Visible = false })
        }
    }

    self.renderConnection = runService.Heartbeat:Connect(function()
        self:Update()
        self:Render()
    end)
end

function EspObject:Destruct()
    if self.renderConnection then
        self.renderConnection:Disconnect()
    end
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
    self.weapon = interface.getWeapon(self.player)
    self.enabled = self.options.enabled and self.character and not
        (#interface.whitelist > 0 and not find(interface.whitelist, self.player.UserId))

    local head = self.enabled and findFirstChild(self.character, "Head")
    if not head then
        self.charCache = {}
        self.onScreen = false
        return
    end

    local _, onScreen, depth = worldToScreen(head.Position)
    self.onScreen = onScreen
    self.distance = depth

    if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
        self.onScreen = false
    end

    if self.onScreen then
        local cache = self.charCache
        local children = getChildren(self.character)
        if not cache[1] or self.childCount ~= #children then
            clear(cache)
            for i = 1, #children do
                local part = children[i]
                if isA(part, "BasePart") and isBodyPart(part.Name) then
                    cache[#cache + 1] = part
                end
            end
            self.childCount = #children
        end
        self.corners = calculateCorners(getBoundingBox(cache))
    elseif self.options.offScreenArrow then
        local cframe = camera.CFrame
        local flat = fromMatrix(cframe.Position, cframe.RightVector, Vector3.yAxis)
        local objectSpace = pointToObjectSpace(flat, head.Position)
        self.direction = Vector2.new(objectSpace.X, objectSpace.Z).Unit
    end
end

function EspObject:Render()
    if not self.onScreen or not self.enabled then return end
    local visible = self.drawings.visible
    local corners = self.corners
    local options = self.options

    -- box
    visible.box.Visible = options.box
    visible.boxOutline.Visible = visible.box.Visible and options.boxOutline
    if visible.box.Visible then
        local box = visible.box
        box.Position = corners.topLeft
        box.Size = corners.bottomRight - corners.topLeft
        box.Color = parseColor(self, options.boxColor[1])
        box.Transparency = options.boxColor[2]

        local boxOutline = visible.boxOutline
        boxOutline.Position = box.Position
        boxOutline.Size = box.Size
        boxOutline.Color = parseColor(self, options.boxOutlineColor[1], true)
        boxOutline.Transparency = options.boxOutlineColor[2]
    end

    -- health bar (VERTICAL, слева)
    visible.healthBar.Visible = options.healthBar
    visible.healthBarOutline.Visible = visible.healthBar.Visible and options.healthBarOutline
    if visible.healthBar.Visible then
        local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
        local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET

        local healthBar = visible.healthBar
        healthBar.From = lerp2(barTo, barFrom, self.health/self.maxHealth)
        healthBar.To = barTo
        healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, self.health/self.maxHealth)

        local healthBarOutline = visible.healthBarOutline
        healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET
        healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET
        healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true)
        healthBarOutline.Transparency = options.healthBarOutlineColor[2]
    end
end

-- Интерфейс ESP
local EspInterface = {
    _hasLoaded = false,
    _objectCache = {},
    whitelist = {},
    sharedSettings = {
        textSize = 13,
        textFont = 2,
        limitDistance = false,
        maxDistance = 150,
        useTeamColor = false
    },
    teamSettings = {
        enemy = {
            enabled = true,
            box = true,
            boxColor = { Color3.new(1,0,0), 1 },
            boxOutline = true,
            boxOutlineColor = { Color3.new(), 1 },
            healthBar = true,
            healthyColor = Color3.new(0,1,0),
            dyingColor = Color3.new(1,0,0),
            healthBarOutline = true,
            healthBarOutlineColor = { Color3.new(), 0.5 }
        },
        friendly = {
            enabled = true,
            box = true,
            boxColor = { Color3.new(0,1,0), 1 },
            boxOutline = true,
            boxOutlineColor = { Color3.new(), 1 },
            healthBar = true,
            healthyColor = Color3.new(0,1,0),
            dyingColor = Color3.new(1,0,0),
            healthBarOutline = true,
            healthBarOutlineColor = { Color3.new(), 0.5 }
        }
    }
}

function EspInterface.getCharacter(player)
    return player.Character
end

function EspInterface.getHealth(player)
    local char = EspInterface.getCharacter(player)
    local humanoid = char and findFirstChildOfClass(char, "Humanoid")
    if humanoid then return humanoid.Health, humanoid.MaxHealth end
    return 100,100
end

function EspInterface.isFriendly(player)
    return player.Team and player.Team == localPlayer.Team
end

function EspInterface.getWeapon(player)
    return "Unknown"
end

function EspInterface.getTeamColor(player)
    return player.Team and player.Team.TeamColor and player.Team.TeamColor.Color
end

function EspInterface.Load()
    if EspInterface._hasLoaded then return end
    local function createObject(player)
        if player ~= localPlayer then
            EspInterface._objectCache[player] = { EspObject.new(player, EspInterface) }
        end
    end
    local function removeObject(player)
        local object = EspInterface._objectCache[player]
        if object then
            for i = 1, #object do object[i]:Destruct() end
            EspInterface._objectCache[player] = nil
        end
    end
    for _, plr in ipairs(players:GetPlayers()) do createObject(plr) end
    EspInterface.playerAdded = players.PlayerAdded:Connect(createObject)
    EspInterface.playerRemoving = players.PlayerRemoving:Connect(removeObject)
    EspInterface._hasLoaded = true
end

function EspInterface.Unload()
    if not EspInterface._hasLoaded then return end
    for _, object in next, EspInterface._objectCache do
        for i = 1, #object do object[i]:Destruct() end
    end
    EspInterface._objectCache = {}
    EspInterface.playerAdded:Disconnect()
    EspInterface.playerRemoving:Disconnect()
    EspInterface._hasLoaded = false
end

return EspInterface
