--!strict
--[[
    AbilityController.luau
    Client ability input, cooldown tracking, and visual event handler.
]]

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AbilityConfig = require(ReplicatedStorage.LootArena.Config.AbilityConfig)
local Remotes = require(ReplicatedStorage.LootArena.Network.Remotes)
local VisualFX = require(ReplicatedStorage.LootArena.Shared.VisualFX)

local AbilityController = {}

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

-- Cooldown tracker: [AbilityId] = ExpiryTimestamp
local localCooldowns: { [string]: number } = {}
local onCooldownChangedCallbacks: { (abilityId: string, duration: number, remaining: number) -> () } = {}

function AbilityController.onCooldownChanged(callback: (abilityId: string, duration: number, remaining: number) -> ())
    table.insert(onCooldownChangedCallbacks, callback)
end

function AbilityController.isAbilityReady(abilityId: string): boolean
    local expiry = localCooldowns[abilityId] or 0
    return os.clock() >= expiry
end

function AbilityController.getCooldownRemaining(abilityId: string): number
    local expiry = localCooldowns[abilityId] or 0
    return math.max(0, expiry - os.clock())
end

local function triggerCooldown(abilityId: string, duration: number)
    local now = os.clock()
    localCooldowns[abilityId] = now + duration
    for _, cb in ipairs(onCooldownChangedCallbacks) do
        task.spawn(cb, abilityId, duration, duration)
    end
end

-- Fire Dash
function AbilityController.castDash()
    if not AbilityController.isAbilityReady("Dash") then return end

    local character = localPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or humanoid.Health <= 0 or not rootPart then return end

    -- Cannot dash while celebrating with the Ruby dance
    if character:GetAttribute("IsDancing") == true then
        return
    end

    -- Determine dash direction based on player input or camera
    local moveDir = humanoid.MoveDirection
    local direction: Vector3
    if moveDir.Magnitude > 0.1 then
        direction = moveDir.Unit
    else
        local look = rootPart.CFrame.LookVector
        direction = Vector3.new(look.X, 0, look.Z).Unit
    end

    local cfg = AbilityConfig.Abilities.Dash
    triggerCooldown("Dash", cfg.Cooldown)

    -- Apply powerful, responsive impulse that guarantees character movement
    local impulsePower = cfg.Stats.ImpulsePower or 130
    local duration = cfg.Stats.Duration or 0.24

    -- 1. Direct assembly velocity
    rootPart.AssemblyLinearVelocity = Vector3.new(direction.X * impulsePower, 5, direction.Z * impulsePower)

    -- 2. Sustained BodyVelocity to prevent Humanoid ground friction from stopping it
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "DashVelocity"
    bodyVelocity.MaxForce = Vector3.new(2000000, 5000, 2000000)
    bodyVelocity.Velocity = Vector3.new(direction.X * impulsePower, 0, direction.Z * impulsePower)
    bodyVelocity.Parent = rootPart

    -- Immediate zero-latency local FX and sound
    VisualFX.playDashEffect(character, direction)

    task.delay(duration, function()
        if bodyVelocity and bodyVelocity.Parent then
            bodyVelocity:Destroy()
        end
    end)

    -- Send to server to validate cooldown and replicate to other players
    Remotes.getEvent("UseAbility"):FireServer("Dash", {
        Direction = direction,
    })
end

-- Fire Fireball
function AbilityController.castFireball()
    if not AbilityController.isAbilityReady("Fireball") then return end

    local character = localPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or humanoid.Health <= 0 or not rootPart then return end

    local targetHit = mouse.Hit
    local targetPos = if targetHit then targetHit.Position else (rootPart.Position + rootPart.CFrame.LookVector * 100)
    local origin = rootPart.Position + Vector3.new(0, 1.2, 0)
    local direction = (targetPos - origin).Unit

    local cfg = AbilityConfig.Abilities.Fireball
    triggerCooldown("Fireball", cfg.Cooldown)

    -- Send to server
    Remotes.getEvent("UseAbility"):FireServer("Fireball", {
        Direction = direction,
    })
end

function AbilityController.init()
    local useAbilityRemote = Remotes.getEvent("UseAbility")
    local abilityTriggeredRemote = Remotes.getEvent("AbilityTriggered")
    local damageIndicatorRemote = Remotes.getEvent("DamageIndicator")

    -- Listen for server visual replication
    abilityTriggeredRemote.OnClientEvent:Connect(function(casterPlayer: Player, abilityId: string, data: { [string]: any })
        if abilityId == "Dash" then
            -- Replicate dash FX for other players (local player already rendered it immediately)
            if casterPlayer and casterPlayer ~= localPlayer and casterPlayer.Character then
                VisualFX.playDashEffect(casterPlayer.Character, data.Direction or Vector3.new(0, 0, 1))
            end
        elseif abilityId == "Fireball" then
            -- Render client projectile
            local origin = data.Origin or Vector3.zero
            local dir = data.Direction or Vector3.new(0, 0, 1)
            local speed = data.Speed or 110

            local orb = VisualFX.createProjectileModel(origin)
            task.spawn(function()
                local pos = origin
                local startTime = os.clock()
                while orb and orb.Parent and (os.clock() - startTime) < 3.0 do
                    local dt = task.wait(0.02)
                    pos = pos + (dir * speed * dt)
                    orb.Position = pos
                end
                if orb and orb.Parent then
                    orb:Destroy()
                end
            end)
        elseif abilityId == "FireballImpact" then
            local pos = data.Position or Vector3.zero
            local radius = data.Radius or 8.0
            VisualFX.playExplosionEffect(pos, radius)
        end
    end)

    -- Damage numbers
    damageIndicatorRemote.OnClientEvent:Connect(function(position: Vector3, damage: number)
        VisualFX.showDamageIndicator(position, damage)
    end)

    -- Bind Inputs
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.Q then
            AbilityController.castDash()
        elseif input.KeyCode == Enum.KeyCode.E then
            AbilityController.castFireball()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            AbilityController.castFireball()
        end
    end)
end

return AbilityController
