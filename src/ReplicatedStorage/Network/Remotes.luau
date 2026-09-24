--!strict
--[[
    Remotes.luau
    Centralized RemoteEvent management. Creates remotes automatically if on server,
    and reliably retrieves them on the client.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local REMOTE_EVENTS = {
    "UseAbility",         -- Client -> Server: (abilityId: string, clientData: table)
    "AbilityTriggered",   -- Server -> Client: (player: Player, abilityId: string, data: table)
    "LootCollectedFX",    -- Server -> Client: (position: Vector3, lootType: string, value: number)
    "DamageIndicator",    -- Server -> Client: (position: Vector3, damage: number, isCritical: boolean)
}

local remotesFolder: Folder

local function getFolder(): Folder
    if remotesFolder then
        return remotesFolder
    end

    local rootFolder = ReplicatedStorage:FindFirstChild("LootArena")
    if not rootFolder then
        if RunService:IsServer() then
            rootFolder = Instance.new("Folder")
            rootFolder.Name = "LootArena"
            rootFolder.Parent = ReplicatedStorage
        else
            rootFolder = ReplicatedStorage:WaitForChild("LootArena", 10) :: Folder
        end
    end

    local folder = rootFolder:FindFirstChild("Remotes") :: Folder?
    if not folder then
        if RunService:IsServer() then
            folder = Instance.new("Folder")
            folder.Name = "Remotes"
            folder.Parent = rootFolder
        else
            folder = rootFolder:WaitForChild("Remotes", 10) :: Folder
        end
    end

    remotesFolder = folder
    return folder
end

function Remotes.init()
    local folder = getFolder()
    if RunService:IsServer() then
        for _, remoteName in ipairs(REMOTE_EVENTS) do
            if not folder:FindFirstChild(remoteName) then
                local event = Instance.new("RemoteEvent")
                event.Name = remoteName
                event.Parent = folder
            end
        end
    end
end

function Remotes.getEvent(name: string): RemoteEvent
    local folder = getFolder()
    local event = folder:FindFirstChild(name) :: RemoteEvent?
    if not event then
        if RunService:IsServer() then
            event = Instance.new("RemoteEvent")
            event.Name = name
            event.Parent = folder
        else
            event = folder:WaitForChild(name, 10) :: RemoteEvent
        end
    end
    return event :: RemoteEvent
end

return Remotes
