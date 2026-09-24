--!strict
--[[
    LootService.luau
    Server-authoritative loot lifecycle manager:
    - Spawns OOP Gem entities across designated nodes
    - Validates player touch & distance on server
    - Prevents race conditions and double pickups atomically
    - Awards loot to player's stats
    - Replicates collection FX and triggers respawn cycles
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootConfig = require(ReplicatedStorage.LootArena.Config.LootConfig)
local Remotes = require(ReplicatedStorage.LootArena.Network.Remotes)
local PlayerService = require(script.Parent.PlayerService)
local Gem = require(script.Parent.Gem)

local LootService = {}

local activeLootFolder: Folder
local lootNodes: { BasePart } = {}
local occupiedNodes: { [string]: boolean } = {}
local activeGems: { [string]: any } = {}

-- Helper to count currently active Rubies in the arena
local function getActiveRubyCount(): number
    if not activeLootFolder then return 0 end
    local count = 0
    for _, item in ipairs(activeLootFolder:GetChildren()) do
        if item:GetAttribute("LootType") == "Ruby" and item:GetAttribute("IsCollected") ~= true then
            count += 1
        end
    end
    return count
end

-- Select random loot type weighted by config (guarantees at least 1 Ruby in the session)
local function pickRandomLootType(): LootConfig.LootTypeInfo
    if getActiveRubyCount() == 0 then
        for _, t in ipairs(LootConfig.TYPES) do
            if t.Name == "Ruby" then
                return t
            end
        end
    end

    local totalWeight = 0
    for _, t in ipairs(LootConfig.TYPES) do
        totalWeight += t.Weight
    end

    local roll = math.random() * totalWeight
    local current = 0
    for _, t in ipairs(LootConfig.TYPES) do
        current += t.Weight
        if roll <= current then
            return t
        end
    end
    return LootConfig.TYPES[1]
end

-- Process pickup validation and award stats
local function handlePickup(gem: any, hitPart: BasePart)
    if not gem or gem.IsCollected then return end

    local character = hitPart.Parent
    if not character or not character:IsA("Model") then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or humanoid.Health <= 0 or not rootPart then return end

    local gemPos = gem:GetPosition()
    local distance = (rootPart.Position - gemPos).Magnitude
    if distance > (LootConfig.PICKUP_RADIUS + 4) then
        return -- Suspicious distance, reject collection
    end

    if not gem:Collect() then
        return
    end

    local value = gem.Value
    local lootType = gem.LootType
    local nodeName = gem.NodeName

    PlayerService.addLoot(player, value)
    Remotes.getEvent("LootCollectedFX"):FireAllClients(gemPos, lootType, value, player)

    activeGems[nodeName] = nil
    gem:Destroy()

    if nodeName ~= "" then
        task.delay(math.random(LootConfig.RESPAWN_DELAY_MIN, LootConfig.RESPAWN_DELAY_MAX), function()
            occupiedNodes[nodeName] = false
            LootService.spawnLootAtNodeName(nodeName)
        end)
    end
end

function LootService.spawnLootAtNode(node: BasePart)
    if occupiedNodes[node.Name] then return end
    occupiedNodes[node.Name] = true

    local lootInfo = pickRandomLootType()
    local newGem = Gem.new(node, lootInfo, handlePickup)
    activeGems[node.Name] = newGem
end

function LootService.spawnLootAtNodeName(nodeName: string)
    for _, node in ipairs(lootNodes) do
        if node.Name == nodeName then
            LootService.spawnLootAtNode(node)
            break
        end
    end
end

function LootService.replenishAllNodes()
    for _, node in ipairs(lootNodes) do
        if not occupiedNodes[node.Name] then
            LootService.spawnLootAtNode(node)
        end
    end
end

function LootService.init()
    activeLootFolder = workspace:FindFirstChild("ActiveLoot") :: Folder
    if not activeLootFolder then
        activeLootFolder = Instance.new("Folder")
        activeLootFolder.Name = "ActiveLoot"
        activeLootFolder.Parent = workspace
    end

    local mapFolder = workspace:WaitForChild("ArenaMap", 10)
    if mapFolder then
        local nodesFolder = mapFolder:WaitForChild("LootSpawnNodes", 5) :: Folder?
        if nodesFolder then
            for _, child in ipairs(nodesFolder:GetChildren()) do
                if child:IsA("BasePart") then
                    table.insert(lootNodes, child)
                end
            end
        end
    end

    LootService.replenishAllNodes()

    task.spawn(function()
        while true do
            task.wait(LootConfig.SPAWN_CHECK_INTERVAL)
            local currentCount = #activeLootFolder:GetChildren()
            if currentCount < LootConfig.MAX_ACTIVE_LOOT then
                for _, node in ipairs(lootNodes) do
                    if not occupiedNodes[node.Name] then
                        LootService.spawnLootAtNode(node)
                        break
                    end
                end
            end
        end
    end)
end

return LootService
