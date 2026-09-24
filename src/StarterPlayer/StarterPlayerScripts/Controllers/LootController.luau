--!strict
--[[
    LootController.luau
    Client controller for loot items:
    - Smooth 60 FPS floating and spinning animation for crystals
    - Listens to LootCollectedFX for audio-visual feedback
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LootConfig = require(ReplicatedStorage.LootArena.Config.LootConfig)
local Remotes = require(ReplicatedStorage.LootArena.Network.Remotes)
local VisualFX = require(ReplicatedStorage.LootArena.Shared.VisualFX)

local LootController = {}

local localPlayer = Players.LocalPlayer
local basePositions: { [BasePart]: Vector3 } = {}

function LootController.init()
    local lootCollectedEvent = Remotes.getEvent("LootCollectedFX")

    lootCollectedEvent.OnClientEvent:Connect(function(position: Vector3, lootType: string, value: number, collectorPlayer: Player?)
        -- Determine color from config
        local color = Color3.fromRGB(46, 204, 113)
        for _, t in ipairs(LootConfig.TYPES) do
            if t.Name == lootType then
                color = t.Color
                break
            end
        end

        -- Pickup sparkle ring & sound
        VisualFX.playLootPickupEffect(position, color)

        -- If it's a rare Ruby, trigger the celebratory Ruby Dance for all players to see!
        if lootType == "Ruby" and collectorPlayer and collectorPlayer.Character then
            VisualFX.playRubyDance(collectorPlayer.Character)
        end
    end)

    -- Animate active loot crystals smoothly on render step
    RunService.RenderStepped:Connect(function(dt: number)
        local crystals = CollectionService:GetTagged("LootCrystal")
        local t = os.clock()

        for _, crystal in ipairs(crystals) do
            if crystal:IsA("BasePart") and crystal.Parent then
                local basePos = basePositions[crystal]
                if not basePos then
                    basePos = crystal.Position
                    basePositions[crystal] = basePos
                end

                local nodeOffset = (crystal:GetAttribute("SpawnTime") :: number?) or 0
                local bobY = math.sin((t + nodeOffset) * 2.5) * 0.45
                local currentCFrame = CFrame.new(basePos + Vector3.new(0, bobY, 0))
                crystal.CFrame = currentCFrame * CFrame.Angles(0, (t * 2.0) % (math.pi * 2), math.sin(t * 1.5) * 0.1)
            end
        end

        -- Clean up removed crystals from cache
        for part, _ in pairs(basePositions) do
            if not part.Parent then
                basePositions[part] = nil
            end
        end
    end)
end

return LootController
