--!strict
--[[
    ClientMain.client.luau
    Master client initializer for LootArena.
]]

print("[LootArena] Initializing client systems...")

local Controllers = script.Parent.Controllers

local LootController = require(Controllers.LootController)
local AbilityController = require(Controllers.AbilityController)
local UIController = require(Controllers.UIController)

-- 1. Initialize Loot visual effects and floating controller
LootController.init()

-- 2. Initialize Ability inputs, networking, and combat replication
AbilityController.init()

-- 3. Initialize HUD, health bar, and cooldown interface
UIController.init()

print("[LootArena] Client systems loaded successfully!")
