--!strict
--[[
    Gem.luau
    Authoritative OOP class representing a collectible Gem entity.
    - Clones template model/mesh from ReplicatedStorage if available
    - If built without templates, procedurally applies authentic 3D crystal MeshIds
    - Auto-scales geometry to uniform target dimensions (2.5 studs)
    - Encapsulates physics, collision, tags, overhead UI, and lifecycle disposal
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LootConfig = require(ReplicatedStorage.LootArena.Config.LootConfig)

local Gem = {}
Gem.__index = Gem

export type GemType = {
    Instance: Instance,
    Node: BasePart,
    LootType: string,
    Value: number,
    NodeName: string,
    IsCollected: boolean,
    Connections: { RBXScriptConnection },

    GetPosition: (self: GemType) -> Vector3,
    Collect: (self: GemType) -> boolean,
    Destroy: (self: GemType) -> (),
}

-- Authentic crystal 3D meshes (Using the verified gemstone mesh)
local CRYSTAL_MESH_IDS = {
    Emerald = "rbxassetid://4653175325",   -- Gemstone mesh (Emerald green)
    Sapphire = "rbxassetid://4653175325",  -- Gemstone mesh (Sapphire blue)
    Ruby = "rbxassetid://4653175325",      -- Gemstone mesh (Ruby red)
}

-- Robust template lookup across ReplicatedStorage
local function findTemplate(lootName: string): Instance?
    local root = ReplicatedStorage:FindFirstChild("LootArena")
    local assets = root and root:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
    local lootFolder = assets and assets:FindFirstChild("Loot")
    if lootFolder and lootFolder:FindFirstChild(lootName) then
        return lootFolder:FindFirstChild(lootName)
    end

    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc.Name == "Loot" and desc:IsA("Folder") and desc:FindFirstChild(lootName) then
            return desc:FindFirstChild(lootName)
        end
    end
    return nil
end

-- Constructor
function Gem.new(node: BasePart, lootInfo: LootConfig.LootTypeInfo, onTouchedCallback: (gem: any, hit: BasePart) -> ()): GemType
    local self = setmetatable({}, Gem)

    self.Node = node
    self.LootType = lootInfo.Name
    self.Value = lootInfo.Value
    self.NodeName = node.Name
    self.IsCollected = false
    self.Connections = {}

    local template = findTemplate(lootInfo.Name)
    local item: Instance

    if template then
        item = template:Clone()
    else
        -- Procedural 3D Crystal Mesh (Guaranteed 3D faceted gem, never a cube!)
        local part = Instance.new("Part")
        part.Name = "Loot_" .. lootInfo.Name
        part.Size = Vector3.new(2.2, 2.8, 2.2)
        part.Material = Enum.Material.Glass
        part.Color = lootInfo.Color
        part.Transparency = 0.15

        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = CRYSTAL_MESH_IDS[lootInfo.Name] or "rbxassetid://4653175325"
        
        -- Exact compact scale for raw asset meshes (~2.4 studs tall)
        local meshScale = if lootInfo.Name == "Ruby" then 0.11 elseif lootInfo.Name == "Emerald" then 0.08 else 0.08
        mesh.Scale = Vector3.new(meshScale, meshScale, meshScale)
        mesh.Parent = part

        -- Sparkle particle emitter
        local sparkles = Instance.new("ParticleEmitter")
        sparkles.Texture = "rbxassetid://241594419"
        sparkles.Color = ColorSequence.new(lootInfo.Color)
        sparkles.Size = NumberSequence.new(0.3, 0)
        sparkles.Lifetime = NumberRange.new(0.5, 1.0)
        sparkles.Rate = 4
        sparkles.Speed = NumberRange.new(1, 2)
        sparkles.SpreadAngle = Vector2.new(180, 180)
        sparkles.Parent = part

        item = part
    end

    self.Instance = item

    -- Configure PrimaryPart if it's a Model
    if item:IsA("Model") and not item.PrimaryPart then
        local primary = item:FindFirstChildWhichIsA("BasePart")
        if primary then
            item.PrimaryPart = primary
        end
    end

    -- Also scale down any existing SpecialMesh inside cloned templates
    for _, desc in ipairs(item:GetDescendants()) do
        if desc:IsA("SpecialMesh") and desc.MeshType == Enum.MeshType.FileMesh then
            local meshScale = if lootInfo.Name == "Ruby" then 0.11 elseif lootInfo.Name == "Emerald" then 0.08 else 0.08
            desc.Scale = Vector3.new(meshScale, meshScale, meshScale)
        end
    end

    -- Auto-scale Models or MeshParts to compact ~2.4 studs height
    local targetHeight = 2.4
    if item:IsA("Model") then
        local _, bounds = item:GetBoundingBox()
        local maxDim = math.max(bounds.X, bounds.Y, bounds.Z)
        if maxDim > 0 and maxDim > targetHeight then
            item:ScaleTo(targetHeight / maxDim)
        end
    elseif item:IsA("BasePart") then
        item.Size = Vector3.new(1.8, 2.4, 1.8)
    end

    -- Set collision and touch listeners
    local function setupPart(part: BasePart)
        part.CanCollide = false
        part.CanTouch = true
        part.Anchored = true
        part.CastShadow = false

        local conn = part.Touched:Connect(function(hit)
            onTouchedCallback(self, hit)
        end)
        table.insert(self.Connections, conn)
    end

    if item:IsA("Model") then
        for _, desc in ipairs(item:GetDescendants()) do
            if desc:IsA("BasePart") then
                setupPart(desc)
            end
        end
    elseif item:IsA("BasePart") then
        setupPart(item)
    end

    -- Position at spawn node
    local spawnCF = node.CFrame + Vector3.new(0, 1.2, 0)
    if item:IsA("Model") then
        item:PivotTo(spawnCF)
    elseif item:IsA("BasePart") then
        item.CFrame = spawnCF
    end

    -- Add glowing PointLight
    local targetPart: BasePart? = if item:IsA("Model") then (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) else (item :: BasePart)
    if targetPart then
        if not item:FindFirstChildWhichIsA("PointLight", true) then
            local light = Instance.new("PointLight")
            light.Name = "GemLight"
            light.Color = lootInfo.Color
            light.Range = 8
            light.Brightness = 2
            light.Parent = targetPart
        end

        -- Overhead tag
        if not item:FindFirstChildWhichIsA("BillboardGui", true) then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "LootTag"
            billboard.Size = UDim2.new(0, 120, 0, 40)
            billboard.StudsOffset = Vector3.new(0, 2.2, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = targetPart

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.FredokaOne
            label.Text = string.format("💎 %s (+%d)", lootInfo.Name, lootInfo.Value)
            label.TextColor3 = lootInfo.Color
            label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            label.TextStrokeTransparency = 0.1
            label.TextSize = 18
            label.Parent = billboard
        end
    end

    -- Metadata attributes & client animation tag
    item:SetAttribute("LootType", self.LootType)
    item:SetAttribute("Value", self.Value)
    item:SetAttribute("NodeName", self.NodeName)
    item:SetAttribute("IsCollected", false)
    item:SetAttribute("SpawnTime", workspace:GetServerTimeNow())
    item:AddTag("LootCrystal")

    local activeLootFolder = workspace:FindFirstChild("ActiveLoot")
    if not activeLootFolder then
        activeLootFolder = Instance.new("Folder")
        activeLootFolder.Name = "ActiveLoot"
        activeLootFolder.Parent = workspace
    end
    item.Parent = activeLootFolder

    return (self :: any)
end

function Gem:GetPosition(): Vector3
    if self.Instance:IsA("Model") then
        return self.Instance:GetPivot().Position
    elseif self.Instance:IsA("BasePart") then
        return self.Instance.Position
    end
    return self.Node.Position
end

function Gem:Collect(): boolean
    if self.IsCollected then return false end
    self.IsCollected = true
    if self.Instance then
        self.Instance:SetAttribute("IsCollected", true)
    end
    return true
end

function Gem:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    table.clear(self.Connections)
    if self.Instance then
        self.Instance:Destroy()
    end
end

return Gem
