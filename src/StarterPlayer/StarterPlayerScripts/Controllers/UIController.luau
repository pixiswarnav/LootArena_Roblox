--!strict
--[[
    UIController.luau
    Clean, responsive HUD:
    - Loot counter with icon and bounce animations
    - Ability slots with cooldown indicators and keybind badges
    - Health bar tracking current player HP
    - Quick controls reference
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityConfig = require(ReplicatedStorage.LootArena.Config.AbilityConfig)
local AbilityController = require(script.Parent.AbilityController)

local UIController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local lootCountLabel: TextLabel
local lootCard: Frame
local healthFill: Frame
local healthText: TextLabel

local cooldownFrames: { [string]: { Overlay: Frame, Text: TextLabel } } = {}

-- Utility to create rounded borders
local function addCorner(parent: Instance, radius: number)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end

local function addStroke(parent: Instance, color: Color3, thickness: number, transparency: number)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness
    stroke.Transparency = transparency or 0
    stroke.Parent = parent
    return stroke
end

function UIController.buildHUD()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LootArenaHUD"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- ============================================================
    -- 1. LOOT COUNTER (Top Center)
    -- ============================================================
    lootCard = Instance.new("Frame")
    lootCard.Name = "LootCard"
    lootCard.Size = UDim2.new(0, 180, 0, 50)
    lootCard.Position = UDim2.new(0.5, -90, 0, 20)
    lootCard.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
    lootCard.BackgroundTransparency = 0.15
    addCorner(lootCard, 12)
    addStroke(lootCard, Color3.fromRGB(46, 204, 113), 2, 0.2)
    lootCard.Parent = screenGui

    -- Crystal Icon
    local gemIcon = Instance.new("TextLabel")
    gemIcon.Name = "GemIcon"
    gemIcon.Size = UDim2.new(0, 40, 1, 0)
    gemIcon.Position = UDim2.new(0, 10, 0, 0)
    gemIcon.BackgroundTransparency = 1
    gemIcon.Text = "💎"
    gemIcon.TextSize = 26
    gemIcon.Parent = lootCard

    -- Loot Text
    lootCountLabel = Instance.new("TextLabel")
    lootCountLabel.Name = "LootCount"
    lootCountLabel.Size = UDim2.new(1, -60, 1, 0)
    lootCountLabel.Position = UDim2.new(0, 50, 0, 0)
    lootCountLabel.BackgroundTransparency = 1
    lootCountLabel.Font = Enum.Font.FredokaOne
    lootCountLabel.Text = "Loot: 0"
    lootCountLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    lootCountLabel.TextSize = 22
    lootCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    lootCountLabel.Parent = lootCard

    -- ============================================================
    -- 2. HEALTH BAR (Top Left)
    -- ============================================================
    local healthCard = Instance.new("Frame")
    healthCard.Name = "HealthCard"
    healthCard.Size = UDim2.new(0, 220, 0, 45)
    healthCard.Position = UDim2.new(0, 25, 0, 20)
    healthCard.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
    healthCard.BackgroundTransparency = 0.15
    addCorner(healthCard, 10)
    addStroke(healthCard, Color3.fromRGB(60, 65, 80), 1.5, 0.4)
    healthCard.Parent = screenGui

    local healthBg = Instance.new("Frame")
    healthBg.Name = "HealthBg"
    healthBg.Size = UDim2.new(1, -20, 0, 14)
    healthBg.Position = UDim2.new(0, 10, 0, 22)
    healthBg.BackgroundColor3 = Color3.fromRGB(40, 44, 55)
    addCorner(healthBg, 6)
    healthBg.Parent = healthCard

    healthFill = Instance.new("Frame")
    healthFill.Name = "HealthFill"
    healthFill.Size = UDim2.new(1, 0, 1, 0)
    healthFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    addCorner(healthFill, 6)
    healthFill.Parent = healthBg

    healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Size = UDim2.new(1, -20, 0, 18)
    healthText.Position = UDim2.new(0, 10, 0, 3)
    healthText.BackgroundTransparency = 1
    healthText.Font = Enum.Font.FredokaOne
    healthText.Text = "HP: 100 / 100"
    healthText.TextColor3 = Color3.fromRGB(220, 220, 220)
    healthText.TextSize = 13
    healthText.TextXAlignment = Enum.TextXAlignment.Left
    healthText.Parent = healthCard

    -- ============================================================
    -- 3. ABILITY ACTION BAR (Bottom Center)
    -- ============================================================
    local actionBar = Instance.new("Frame")
    actionBar.Name = "ActionBar"
    actionBar.Size = UDim2.new(0, 170, 0, 80)
    actionBar.Position = UDim2.new(0.5, -85, 1, -100)
    actionBar.BackgroundTransparency = 1
    actionBar.Parent = screenGui

    local abilityList = { "Dash", "Fireball" }
    for i, abId in ipairs(abilityList) do
        local ab = AbilityConfig.Abilities[abId]
        if not ab then continue end

        local slot = Instance.new("TextButton")
        slot.Name = "Slot_" .. abId
        slot.Size = UDim2.new(0, 75, 0, 75)
        slot.Position = UDim2.new(0, (i - 1) * 90, 0, 0)
        slot.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
        slot.BackgroundTransparency = 0.1
        slot.Text = ""
        addCorner(slot, 14)
        addStroke(slot, ab.Color, 2, 0.1)
        slot.Parent = actionBar

        -- Icon / Emoji
        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(1, 0, 0, 36)
        icon.Position = UDim2.new(0, 0, 0, 8)
        icon.BackgroundTransparency = 1
        icon.Text = if abId == "Dash" then "⚡" else "🔥"
        icon.TextSize = 28
        icon.Parent = slot

        -- Ability Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 16)
        nameLabel.Position = UDim2.new(0, 0, 0, 48)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.FredokaOne
        nameLabel.Text = if abId == "Dash" then "DASH" else "FIRE"
        nameLabel.TextColor3 = ab.Color
        nameLabel.TextSize = 13
        nameLabel.Parent = slot

        -- Keybind Badge
        local keyBadge = Instance.new("Frame")
        keyBadge.Size = UDim2.new(0, 22, 0, 22)
        keyBadge.Position = UDim2.new(1, -14, 0, -8)
        keyBadge.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
        addCorner(keyBadge, 6)
        addStroke(keyBadge, Color3.fromRGB(180, 180, 180), 1, 0.2)
        keyBadge.Parent = slot

        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(1, 0, 1, 0)
        keyLabel.BackgroundTransparency = 1
        keyLabel.Font = Enum.Font.FredokaOne
        keyLabel.Text = if abId == "Dash" then "Q" else "E"
        keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        keyLabel.TextSize = 13
        keyLabel.Parent = keyBadge

        -- Cooldown Overlay
        local cdOverlay = Instance.new("Frame")
        cdOverlay.Name = "CooldownOverlay"
        cdOverlay.Size = UDim2.new(1, 0, 1, 0)
        cdOverlay.Position = UDim2.new(0, 0, 0, 0)
        cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        cdOverlay.BackgroundTransparency = 0.5
        cdOverlay.Visible = false
        addCorner(cdOverlay, 14)
        cdOverlay.Parent = slot

        local cdText = Instance.new("TextLabel")
        cdText.Name = "CooldownText"
        cdText.Size = UDim2.new(1, 0, 1, 0)
        cdText.BackgroundTransparency = 1
        cdText.Font = Enum.Font.FredokaOne
        cdText.TextColor3 = Color3.fromRGB(255, 255, 255)
        cdText.TextSize = 20
        cdText.Parent = cdOverlay

        cooldownFrames[abId] = {
            Overlay = cdOverlay,
            Text = cdText,
        }

        -- Click handler for mobile / mouse touch
        slot.MouseButton1Click:Connect(function()
            if abId == "Dash" then
                AbilityController.castDash()
            elseif abId == "Fireball" then
                AbilityController.castFireball()
            end
        end)
    end

    -- ============================================================
    -- 4. CONTROLS GUIDE (Bottom Right)
    -- ============================================================
    local guideCard = Instance.new("Frame")
    guideCard.Name = "ControlsGuide"
    guideCard.Size = UDim2.new(0, 180, 0, 85)
    guideCard.Position = UDim2.new(1, -200, 1, -105)
    guideCard.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
    guideCard.BackgroundTransparency = 0.35
    addCorner(guideCard, 10)
    addStroke(guideCard, Color3.fromRGB(80, 85, 100), 1, 0.5)
    guideCard.Parent = screenGui

    local guideText = Instance.new("TextLabel")
    guideText.Size = UDim2.new(1, -16, 1, -12)
    guideText.Position = UDim2.new(0, 8, 0, 6)
    guideText.BackgroundTransparency = 1
    guideText.Font = Enum.Font.SourceSans
    guideText.Text = "<b>[Q]</b> Dash\n<b>[E]</b> or <b>[Click]</b> Fireball\n<b>[Touch Loot]</b> Collect Gems"
    guideText.TextColor3 = Color3.fromRGB(200, 200, 210)
    guideText.TextSize = 14
    guideText.RichText = true
    guideText.TextYAlignment = Enum.TextYAlignment.Center
    guideText.Parent = guideCard

    screenGui.Parent = playerGui
end

-- Bounce animation on loot card when loot increases
function UIController.onLootUpdated(newAmount: number)
    if not lootCountLabel then return end
    lootCountLabel.Text = "Loot: " .. tostring(newAmount)

    -- Bounce punch effect
    local tweenIn = TweenService:Create(lootCard, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 200, 0, 56),
        Position = UDim2.new(0.5, -100, 0, 17),
    })
    local tweenOut = TweenService:Create(lootCard, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 180, 0, 50),
        Position = UDim2.new(0.5, -90, 0, 20),
    })
    tweenIn:Play()
    tweenIn.Completed:Connect(function()
        tweenOut:Play()
    end)
end

function UIController.updateHealth(current: number, maxHealth: number)
    if not healthFill or not healthText then return end
    local pct = math.clamp(current / math.max(1, maxHealth), 0, 1)

    healthText.Text = string.format("HP: %d / %d", math.round(current), math.round(maxHealth))

    local fillTween = TweenService:Create(healthFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = if pct > 0.5 then Color3.fromRGB(46, 204, 113)
            elseif pct > 0.25 then Color3.fromRGB(241, 196, 15)
            else Color3.fromRGB(231, 76, 60),
    })
    fillTween:Play()
end

function UIController.init()
    UIController.buildHUD()

    -- Hook up leaderstats for local player
    local function hookLeaderstats()
        local leaderstats = localPlayer:WaitForChild("leaderstats", 10) :: Folder?
        if leaderstats then
            local lootStat = leaderstats:WaitForChild("Loot", 5) :: IntValue?
            if lootStat then
                UIController.onLootUpdated(lootStat.Value)
                lootStat.Changed:Connect(function(val)
                    UIController.onLootUpdated(val)
                end)
            end
        end
    end
    task.spawn(hookLeaderstats)

    -- Hook up Humanoid health
    local function hookCharacter(char: Model)
        local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
        if hum then
            UIController.updateHealth(hum.Health, hum.MaxHealth)
            hum.HealthChanged:Connect(function(health)
                UIController.updateHealth(health, hum.MaxHealth)
            end)
        end
    end

    if localPlayer.Character then
        hookCharacter(localPlayer.Character)
    end
    localPlayer.CharacterAdded:Connect(hookCharacter)

    -- Real-time Cooldown UI updater
    RunService.RenderStepped:Connect(function()
        for abId, cdData in pairs(cooldownFrames) do
            local remaining = AbilityController.getCooldownRemaining(abId)
            if remaining > 0 then
                cdData.Overlay.Visible = true
                cdData.Text.Text = string.format("%.1fs", remaining)
            else
                cdData.Overlay.Visible = false
            end
        end
    end)
end

return UIController
