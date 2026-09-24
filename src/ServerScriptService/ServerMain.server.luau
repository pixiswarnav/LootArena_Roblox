--!strict
--[[
    ServerMain.server.luau
    Master server initializer for LootArena.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[LootArena] Starting server systems...")

-- 1. Initialize Network Remotes
local Remotes = require(ReplicatedStorage.LootArena.Network.Remotes)
Remotes.init()

-- 2. Initialize Player & Combat Service
local PlayerService = require(script.Parent.PlayerService)
PlayerService.init()

-- 3. Initialize Arena & Map Environment
local ArenaManager = require(script.Parent.ArenaManager)
ArenaManager.init()

-- 4. Initialize Server Loot Spawner & Validation
local LootService = require(script.Parent.LootService)
LootService.init()

-- 5. Initialize Ability Mechanics & Validation
local AbilityService = require(script.Parent.AbilityService)
AbilityService.init()

print("[LootArena] Server successfully initialized and ready!")
