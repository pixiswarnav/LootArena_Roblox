--!strict
--[[
    VisualFX.luau
    Clean, procedural client-side visual effects and sounds for abilities,
    combat interactions, and loot pickups.
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VisualFX = {}

-- Play a procedural or standard sound safely
local function playSound(parent: Instance, soundId: string, volume: number, pitch: number): Sound
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume
    sound.Pitch = pitch
    sound.RollOffMaxDistance = 80
    sound.RollOffMinDistance = 10
    sound.Parent = parent
    sound:Play()
    Debris:AddItem(sound, 3)
    return sound
end

-- Dash Visual Effect: Ghost silhouettes + wind ring + speed sound
function VisualFX.playDashEffect(character: Model, direction: Vector3)
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not rootPart then return end

    -- Play whoosh sound
    playSound(rootPart, "rbxassetid://9114223171", 0.7, 1.2) -- Dash sound

    -- Create expanding dash wind ring
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.5, 5, 5)
    ring.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction) * CFrame.Angles(0, math.rad(90), 0)
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(100, 220, 255)
    ring.CanCollide = false
    ring.CanQuery = false
    ring.Anchored = true
    ring.Transparency = 0.3
    ring.Parent = workspace

    local tween = TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 14, 14),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(ring, 0.35)

    -- Ghost silhouettes along movement
    task.spawn(function()
        for i = 1, 4 do
            task.wait(0.04)
            if not character or not character.Parent then break end
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    local ghost = Instance.new("Part")
                    ghost.Size = part.Size
                    ghost.CFrame = part.CFrame
                    ghost.Color = Color3.fromRGB(120, 230, 255)
                    ghost.Material = Enum.Material.Neon
                    ghost.CanCollide = false
                    ghost.CanQuery = false
                    ghost.Anchored = true
                    ghost.Transparency = 0.4
                    ghost.Parent = workspace

                    local ghostTween = TweenService:Create(ghost, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Transparency = 1,
                    })
                    ghostTween:Play()
                    Debris:AddItem(ghost, 0.25)
                end
            end
        end
    end)
end

-- Fireball Launch FX
function VisualFX.createProjectileModel(position: Vector3): BasePart
    local orb = Instance.new("Part")
    orb.Name = "FireballProjectile"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(2, 2, 2)
    orb.CFrame = CFrame.new(position)
    orb.Material = Enum.Material.Neon
    orb.Color = Color3.fromRGB(255, 140, 20)
    orb.CanCollide = false
    orb.CanQuery = false
    orb.Anchored = true

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 160, 50)
    light.Range = 16
    light.Brightness = 3
    light.Parent = orb

    local fire = Instance.new("Fire")
    fire.Color = Color3.fromRGB(255, 120, 20)
    fire.SecondaryColor = Color3.fromRGB(255, 230, 80)
    fire.Size = 4
    fire.Heat = 15
    fire.Parent = orb

    -- Launch sound
    playSound(orb, "rbxassetid://9114221580", 0.6, 1.1)

    orb.Parent = workspace
    return orb
end

-- Fireball Impact / Explosion FX
function VisualFX.playExplosionEffect(position: Vector3, radius: number)
    -- Flash blast sphere
    local blast = Instance.new("Part")
    blast.Shape = Enum.PartType.Ball
    blast.Size = Vector3.new(2, 2, 2)
    blast.Position = position
    blast.Color = Color3.fromRGB(255, 120, 30)
    blast.Material = Enum.Material.Neon
    blast.CanCollide = false
    blast.CanQuery = false
    blast.Anchored = true
    blast.Transparency = 0.1
    blast.Parent = workspace

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 150, 40)
    light.Range = radius * 2
    light.Brightness = 6
    light.Parent = blast

    -- Explosion sound
    playSound(blast, "rbxassetid://9114223171", 0.9, 0.8)

    local tween = TweenService:Create(blast, TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
        Size = Vector3.new(radius * 2, radius * 2, radius * 2),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(blast, 0.4)
end

-- Loot Collection FX: Rising sparkle ring & chime
function VisualFX.playLootPickupEffect(position: Vector3, color: Color3)
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.3, 1.5, 1.5)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.CanCollide = false
    ring.CanQuery = false
    ring.Anchored = true
    ring.Transparency = 0.2
    ring.Parent = workspace

    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = 10
    light.Brightness = 4
    light.Parent = ring

    -- Pickup chime
    playSound(ring, "rbxassetid://9114221580", 0.7, 1.6)

    local tween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 7, 7),
        CFrame = (CFrame.new(position) + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(ring, 0.45)
end

-- Floating Damage Number Indicator
function VisualFX.showDamageIndicator(position: Vector3, damage: number)
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.FredokaOne
    label.Text = "-" .. tostring(math.round(damage))
    label.TextColor3 = Color3.fromRGB(255, 60, 60)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextSize = 24
    label.Parent = billboard

    local anchor = Instance.new("Part")
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Position = position + Vector3.new(math.random(-10, 10) * 0.1, 0, math.random(-10, 10) * 0.1)
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.Anchored = true
    anchor.Parent = workspace
    billboard.Parent = anchor

    local tween = TweenService:Create(billboard, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 5, 0),
    })
    local textTween = TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })
    tween:Play()
    textTween:Play()
    Debris:AddItem(anchor, 0.7)
end

-- Custom Celebratory Dance Animation for Collecting Ruby
function VisualFX.playRubyDance(character: Model)
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end

    -- Mark character as dancing so dashing is disabled
    character:SetAttribute("IsDancing", true)

    -- Play celebratory chime
    playSound(rootPart, "rbxassetid://9114221580", 0.9, 1.8)

    -- Floating celebratory banner overhead
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "RubyDanceTag"
    billboard.Size = UDim2.new(0, 200, 0, 45)
    billboard.StudsOffset = Vector3.new(0, 3.8, 0)
    billboard.AlwaysOnTop = true

    local banner = Instance.new("TextLabel")
    banner.Size = UDim2.new(1, 0, 1, 0)
    banner.BackgroundTransparency = 1
    banner.Font = Enum.Font.FredokaOne
    banner.Text = "✨💃 RUBY DANCE! 🕺✨"
    banner.TextColor3 = Color3.fromRGB(255, 75, 75)
    banner.TextStrokeColor3 = Color3.fromRGB(255, 230, 80)
    banner.TextStrokeTransparency = 0.2
    banner.TextSize = 22
    banner.Parent = billboard
    billboard.Parent = rootPart
    Debris:AddItem(billboard, 2.8)

    -- Confetti Particle Emitter
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxassetid://241594419"
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 200)),
    })
    emitter.Size = NumberSequence.new(0.6, 0)
    emitter.Rate = 35
    emitter.Lifetime = NumberRange.new(1.0, 1.5)
    emitter.Speed = NumberRange.new(8, 15)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Parent = rootPart
    Debris:AddItem(emitter, 2.5)

    -- Load and play full-body dance AnimationTrack through Animator
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local danceTrack: AnimationTrack? = nil

    -- 1. Check character's built-in Animate script for dance emotes
    local animateScript = character:FindFirstChild("Animate")
    local danceFolder = animateScript and animateScript:FindFirstChild("dance")
    if danceFolder then
        local danceEntry = danceFolder:FindFirstChild("dance1") or danceFolder:FindFirstChild("dance2") or danceFolder:FindFirstChildOfClass("Animation")
        if danceEntry and danceEntry:IsA("Animation") then
            danceTrack = animator:LoadAnimation(danceEntry)
        elseif danceEntry and danceEntry:FindFirstChildOfClass("Animation") then
            danceTrack = animator:LoadAnimation(danceEntry:FindFirstChildOfClass("Animation") :: Animation)
        end
    end

    -- 2. Universal fallback dance animation IDs
    if not danceTrack then
        local animObj = Instance.new("Animation")
        if humanoid.RigType == Enum.HumanoidRigType.R15 then
            animObj.AnimationId = "rbxassetid://507771019"
        else
            animObj.AnimationId = "rbxassetid://182435998"
        end
        pcall(function()
            danceTrack = animator:LoadAnimation(animObj)
        end)
    end

    if danceTrack then
        danceTrack.Priority = Enum.AnimationPriority.Action4
        danceTrack.Looped = true
        danceTrack:Play(0.15)
    end

    -- Keep character dancing for 2.6 seconds, then re-enable dash
    task.delay(2.6, function()
        if danceTrack then
            danceTrack:Stop(0.2)
            danceTrack:Destroy()
        end
        if character and character.Parent then
            character:SetAttribute("IsDancing", false)
        end
    end)
end

return VisualFX
