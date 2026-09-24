--!strict
--[[
    ArenaManager.luau
    Sets up the physical arena environment:
    - Floor & boundary walls
    - Player spawn locations
    - Designated loot spawn nodes
    - Ambient lighting & atmosphere
]]

local Lighting = game:GetService("Lighting")

local ArenaManager = {}

local ARENA_SIZE = 160
local WALL_HEIGHT = 16
local WALL_THICKNESS = 4

function ArenaManager.setupLighting()
    Lighting.Brightness = 2.5
    Lighting.ClockTime = 14
    Lighting.GlobalShadows = true
    Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 130)

    -- Atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Density = 0.25
        atmosphere.Offset = 0.25
        atmosphere.Color = Color3.fromRGB(200, 215, 230)
        atmosphere.Decay = Color3.fromRGB(100, 120, 150)
        atmosphere.Glare = 0.2
        atmosphere.Haze = 1.5
        atmosphere.Parent = Lighting
    end

    -- Bloom
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.6
        bloom.Size = 24
        bloom.Threshold = 0.8
        bloom.Parent = Lighting
    end
end

function ArenaManager.buildArena(): Folder
    -- Clean up any existing default Baseplate or default SpawnLocations
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Baseplate" or (child:IsA("SpawnLocation") and not child:IsDescendantOf(workspace:FindFirstChild("ArenaMap") or workspace)) then
            child:Destroy()
        end
    end

    local existingMap = workspace:FindFirstChild("ArenaMap")
    if existingMap then
        return existingMap :: Folder
    end

    local mapFolder = Instance.new("Folder")
    mapFolder.Name = "ArenaMap"
    mapFolder.Parent = workspace

    -- 1. Main Floor Platform
    local floor = Instance.new("Part")
    floor.Name = "ArenaFloor"
    floor.Size = Vector3.new(ARENA_SIZE, 4, ARENA_SIZE)
    floor.Position = Vector3.new(0, -2, 0)
    floor.Material = Enum.Material.Concrete
    floor.Color = Color3.fromRGB(45, 52, 54)
    floor.Anchored = true
    floor.TopSurface = Enum.SurfaceType.Smooth
    floor.Parent = mapFolder

    -- Center Platform Highlight
    local centerRing = Instance.new("Part")
    centerRing.Name = "CenterRing"
    centerRing.Shape = Enum.PartType.Cylinder
    centerRing.Size = Vector3.new(0.5, 36, 36)
    centerRing.CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
    centerRing.Material = Enum.Material.Neon
    centerRing.Color = Color3.fromRGB(0, 184, 148)
    centerRing.Transparency = 0.6
    centerRing.Anchored = true
    centerRing.CanCollide = false
    centerRing.Parent = mapFolder

    -- 2. Perimeter Walls
    local half = ARENA_SIZE / 2
    local wallConfigs = {
        { Size = Vector3.new(ARENA_SIZE, WALL_HEIGHT, WALL_THICKNESS), Pos = Vector3.new(0, WALL_HEIGHT / 2, half) },
        { Size = Vector3.new(ARENA_SIZE, WALL_HEIGHT, WALL_THICKNESS), Pos = Vector3.new(0, WALL_HEIGHT / 2, -half) },
        { Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE), Pos = Vector3.new(half, WALL_HEIGHT / 2, 0) },
        { Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ARENA_SIZE), Pos = Vector3.new(-half, WALL_HEIGHT / 2, 0) },
    }

    for i, cfg in ipairs(wallConfigs) do
        local wall = Instance.new("Part")
        wall.Name = "BoundaryWall_" .. i
        wall.Size = cfg.Size
        wall.Position = cfg.Pos
        wall.Material = Enum.Material.DiamondPlate
        wall.Color = Color3.fromRGB(30, 39, 46)
        wall.Anchored = true
        wall.Parent = mapFolder

        -- Neon Trim on top of wall
        local trim = Instance.new("Part")
        trim.Name = "NeonTrim"
        trim.Size = Vector3.new(
            if cfg.Size.X > cfg.Size.Z then cfg.Size.X else 1.5,
            1.5,
            if cfg.Size.Z > cfg.Size.X then cfg.Size.Z else 1.5
        )
        trim.Position = cfg.Pos + Vector3.new(0, WALL_HEIGHT / 2 + 0.75, 0)
        trim.Material = Enum.Material.Neon
        trim.Color = Color3.fromRGB(0, 206, 201)
        trim.Anchored = true
        trim.Parent = mapFolder
    end

    -- 3. Pillar Obstacles for Cover & Visual Interest
    local pillarPositions = {
        Vector3.new(35, 6, 35),
        Vector3.new(-35, 6, 35),
        Vector3.new(35, 6, -35),
        Vector3.new(-35, 6, -35),
        Vector3.new(0, 6, 45),
        Vector3.new(0, 6, -45),
        Vector3.new(45, 6, 0),
        Vector3.new(-45, 6, 0),
    }

    for i, pos in ipairs(pillarPositions) do
        local pillar = Instance.new("Part")
        pillar.Name = "Pillar_" .. i
        pillar.Shape = Enum.PartType.Cylinder
        pillar.Size = Vector3.new(12, 6, 6)
        pillar.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
        pillar.Material = Enum.Material.Cobblestone
        pillar.Color = Color3.fromRGB(99, 110, 114)
        pillar.Anchored = true
        pillar.Parent = mapFolder
    end

    -- 4. Spawn Locations
    local spawnPositions = {
        Vector3.new(55, 0.5, 0),
        Vector3.new(-55, 0.5, 0),
        Vector3.new(0, 0.5, 55),
        Vector3.new(0, 0.5, -55),
    }

    for i, sPos in ipairs(spawnPositions) do
        local spawn = Instance.new("SpawnLocation")
        spawn.Name = "ArenaSpawn_" .. i
        spawn.Size = Vector3.new(8, 1, 8)
        spawn.Position = sPos
        spawn.Material = Enum.Material.Neon
        spawn.Color = Color3.fromRGB(9, 132, 227)
        spawn.Anchored = true
        spawn.CanCollide = true
        spawn.Duration = 0
        spawn.Parent = mapFolder
    end

    -- 5. Designated Loot Spawn Nodes Folder
    local lootNodesFolder = Instance.new("Folder")
    lootNodesFolder.Name = "LootSpawnNodes"
    lootNodesFolder.Parent = mapFolder

    -- Generate a balanced grid of loot spawn points
    local nodeRadius = 60
    local nodeCount = 18
    for i = 1, nodeCount do
        local angle = (i / nodeCount) * math.pi * 2
        local dist = if i % 2 == 0 then 25 else 52
        local nodePos = Vector3.new(math.cos(angle) * dist, 1.5, math.sin(angle) * dist)

        local node = Instance.new("Part")
        node.Name = "SpawnNode_" .. i
        node.Size = Vector3.new(2, 0.2, 2)
        node.Position = nodePos
        node.Transparency = 1
        node.CanCollide = false
        node.CanQuery = false
        node.Anchored = true
        node.Parent = lootNodesFolder
    end

    -- Extra nodes in the center
    local centerNode = Instance.new("Part")
    centerNode.Name = "SpawnNode_Center"
    centerNode.Size = Vector3.new(2, 0.2, 2)
    centerNode.Position = Vector3.new(0, 1.5, 0)
    centerNode.Transparency = 1
    centerNode.CanCollide = false
    centerNode.CanQuery = false
    centerNode.Anchored = true
    centerNode.Parent = lootNodesFolder

    return mapFolder
end

function ArenaManager.init()
    ArenaManager.setupLighting()
    ArenaManager.buildArena()
end

return ArenaManager
