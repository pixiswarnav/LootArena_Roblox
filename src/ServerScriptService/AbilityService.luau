--!strict
--[[
    AbilityService.luau
    Authoritative ability management:
    - Validates ability activations and enforces server-side cooldowns
    - Executes Dash kinematics on HumanoidRootPart
    - Simulates server-authoritative Projectile raycasting, AoE damage, and knockback
    - Replicates ability events to all clients for multiplayer visibility
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityConfig = require(ReplicatedStorage.LootArena.Config.AbilityConfig)
local Remotes = require(ReplicatedStorage.LootArena.Network.Remotes)
local PlayerService = require(script.Parent.PlayerService)

local AbilityService = {}

-- [UserId] -> [AbilityId] -> ExpiryTimestamp
local playerCooldowns: { [number]: { [string]: number } } = {}

local function isPlayerAlive(player: Player): (boolean, Model?, BasePart?, Humanoid?)
    local character = player.Character
    if not character then return false, nil, nil, nil end
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then
        return false, character, rootPart, humanoid
    end
    return true, character, rootPart, humanoid
end

-- Check and consume cooldown
local function tryUseAbility(player: Player, abilityId: string): boolean
    local ability = AbilityConfig.Abilities[abilityId]
    if not ability then return false end

    local userTable = playerCooldowns[player.UserId]
    if not userTable then
        userTable = {}
        playerCooldowns[player.UserId] = userTable
    end

    local now = os.clock()
    local expiry = userTable[abilityId] or 0
    if now < expiry then
        return false -- Cooldown active
    end

    userTable[abilityId] = now + ability.Cooldown
    return true
end

-- Dash ability execution
local function executeDash(player: Player, clientData: { Direction: Vector3? })
    local alive, character, rootPart, humanoid = isPlayerAlive(player)
    if not alive or not character or not rootPart or not humanoid then return end

    -- Server-side check: player cannot dash while performing Ruby dance
    if character:GetAttribute("IsDancing") == true then
        return
    end

    local ability = AbilityConfig.Abilities.Dash
    local impulsePower = ability.Stats.ImpulsePower or 110

    -- Determine dash direction
    local dir = clientData.Direction
    if not dir or dir.Magnitude < 0.1 then
        dir = rootPart.CFrame.LookVector
    else
        dir = Vector3.new(dir.X, 0, dir.Z).Unit
    end

    -- Apply crisp velocity burst
    rootPart.AssemblyLinearVelocity = Vector3.new(dir.X * impulsePower, rootPart.AssemblyLinearVelocity.Y + 8, dir.Z * impulsePower)

    -- Replicate visual FX to all clients
    Remotes.getEvent("AbilityTriggered"):FireAllClients(player, "Dash", {
        Direction = dir,
        Origin = rootPart.Position,
    })
end

-- Fireball ability execution
local function executeFireball(player: Player, clientData: { Direction: Vector3? })
    local alive, character, rootPart, humanoid = isPlayerAlive(player)
    if not alive or not character or not rootPart or not humanoid then return end

    local ability = AbilityConfig.Abilities.Fireball
    local speed = ability.Stats.Speed or 110
    local damage = ability.Stats.Damage or 35
    local lifetime = ability.Stats.Lifetime or 3.0
    local blastRadius = ability.Stats.BlastRadius or 8.0
    local knockback = ability.Stats.Knockback or 45

    -- Determine launch direction
    local dir = clientData.Direction
    if not dir or dir.Magnitude < 0.1 then
        dir = rootPart.CFrame.LookVector
    else
        dir = dir.Unit
    end

    local origin = rootPart.Position + Vector3.new(0, 1.2, 0) + dir * 3

    -- Broadcast to clients for instant visual feedback and audio
    Remotes.getEvent("AbilityTriggered"):FireAllClients(player, "Fireball", {
        Origin = origin,
        Direction = dir,
        Speed = speed,
    })

    -- Server simulation with Raycasting
    task.spawn(function()
        local currentPos = origin
        local startTime = os.clock()
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = { character, workspace:FindFirstChild("ActiveLoot") }
        raycastParams.IgnoreWater = true

        while (os.clock() - startTime) < lifetime do
            local dt = task.wait(0.03)
            local stepDistance = speed * dt
            local targetPos = currentPos + (dir * stepDistance)

            local rayResult = workspace:Raycast(currentPos, dir * stepDistance, raycastParams)
            if rayResult then
                -- Collision detected
                local hitPos = rayResult.Position
                -- AoE explosion effects & damage
                Remotes.getEvent("AbilityTriggered"):FireAllClients(player, "FireballImpact", {
                    Position = hitPos,
                    Radius = blastRadius,
                })

                -- Check hit targets in blast radius
                local overlapParams = OverlapParams.new()
                overlapParams.FilterType = Enum.RaycastFilterType.Exclude
                overlapParams.FilterDescendantsInstances = { character }

                local hitParts = workspace:GetPartBoundsInRadius(hitPos, blastRadius, overlapParams)
                local damagedHumanoids: { [Humanoid]: boolean } = {}

                for _, part in ipairs(hitParts) do
                    local model = part:FindFirstAncestorOfClass("Model")
                    if model and model ~= character then
                        local targetHum = model:FindFirstChildOfClass("Humanoid")
                        local targetRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?

                        if targetHum and targetHum.Health > 0 and not damagedHumanoids[targetHum] then
                            damagedHumanoids[targetHum] = true

                            local targetPlayer = Players:GetPlayerFromCharacter(model)
                            if targetPlayer then
                                PlayerService.recordHit(targetPlayer, player)
                            end

                            targetHum:TakeDamage(damage)

                            -- Knockback
                            if targetRoot then
                                local pushDir = (targetRoot.Position - hitPos)
                                if pushDir.Magnitude > 0.1 then
                                    pushDir = (pushDir.Unit + Vector3.new(0, 0.5, 0)).Unit
                                    targetRoot.AssemblyLinearVelocity = pushDir * knockback
                                end
                            end

                            -- Display damage popup to all clients
                            Remotes.getEvent("DamageIndicator"):FireAllClients(
                                if targetRoot then targetRoot.Position + Vector3.new(0, 2, 0) else hitPos,
                                damage,
                                false
                            )
                        end
                    end
                end

                return -- Projectile resolved
            end

            currentPos = targetPos
        end
    end)
end

function AbilityService.init()
    Remotes.init()

    local useAbilityEvent = Remotes.getEvent("UseAbility")
    useAbilityEvent.OnServerEvent:Connect(function(player: Player, abilityId: unknown, clientData: unknown)
        if typeof(abilityId) ~= "string" then return end
        local data = (typeof(clientData) == "table" and clientData or {}) :: { [string]: any }

        if not tryUseAbility(player, abilityId) then
            return -- On cooldown or invalid
        end

        if abilityId == "Dash" then
            executeDash(player, data)
        elseif abilityId == "Fireball" then
            executeFireball(player, data)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        playerCooldowns[player.UserId] = nil
    end)
end

return AbilityService
