--!strict
--[[
    PlayerService.luau
    Manages player lifecycle, leaderstats (Loot and Kills), combat tracking,
    and character respawns.
]]

local Players = game:GetService("Players")

local PlayerService = {}

-- Stores metadata for combat attribution: [VictimUserId] = LastAttackerPlayer
local lastAttackerMap: { [number]: Player } = {}

local function setupLeaderstats(player: Player): Folder
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"

    local lootStat = Instance.new("IntValue")
    lootStat.Name = "Loot"
    lootStat.Value = 0
    lootStat.Parent = leaderstats

    local killStat = Instance.new("IntValue")
    killStat.Name = "Kills"
    killStat.Value = 0
    killStat.Parent = leaderstats

    leaderstats.Parent = player
    return leaderstats
end

local function onCharacterAdded(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if not humanoid then return end

    humanoid.MaxHealth = 100
    humanoid.Health = 100

    humanoid.Died:Connect(function()
        local attacker = lastAttackerMap[player.UserId]
        if attacker and attacker ~= player and attacker.Parent then
            PlayerService.addKill(attacker)
        end
        lastAttackerMap[player.UserId] = nil
    end)
end

function PlayerService.recordHit(victimPlayer: Player, attackerPlayer: Player)
    if victimPlayer ~= attackerPlayer then
        lastAttackerMap[victimPlayer.UserId] = attackerPlayer
    end
end

function PlayerService.addLoot(player: Player, amount: number)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local lootStat = leaderstats:FindFirstChild("Loot") :: IntValue?
        if lootStat then
            lootStat.Value += amount
        end
    end
end

function PlayerService.getLoot(player: Player): number
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local lootStat = leaderstats:FindFirstChild("Loot") :: IntValue?
        if lootStat then
            return lootStat.Value
        end
    end
    return 0
end

function PlayerService.addKill(player: Player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local killStat = leaderstats:FindFirstChild("Kills") :: IntValue?
        if killStat then
            killStat.Value += 1
        end
    end
end

function PlayerService.init()
    for _, player in ipairs(Players:GetPlayers()) do
        setupLeaderstats(player)
        if player.Character then
            task.spawn(onCharacterAdded, player, player.Character)
        end
        player.CharacterAdded:Connect(function(char)
            onCharacterAdded(player, char)
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        setupLeaderstats(player)
        player.CharacterAdded:Connect(function(char)
            onCharacterAdded(player, char)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        lastAttackerMap[player.UserId] = nil
    end)
end

return PlayerService
