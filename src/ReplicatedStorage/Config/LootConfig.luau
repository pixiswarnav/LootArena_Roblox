--!strict
--[[
    LootConfig.luau
    Defines loot types, spawn rates, values, and visual styles.
]]

export type LootTypeInfo = {
    Name: string,
    Value: number,
    Color: Color3,
    Material: Enum.Material,
    Size: Vector3,
    Weight: number, -- Spawn probability weight
}

local LootConfig = {
    -- Spawn system limits
    MAX_ACTIVE_LOOT = 18,
    SPAWN_CHECK_INTERVAL = 2.0, -- Seconds between spawner tick checks
    RESPAWN_DELAY_MIN = 4.0,   -- Respawn delay after collection
    RESPAWN_DELAY_MAX = 7.0,
    PICKUP_RADIUS = 5.5,       -- Studs distance threshold for server validation

    -- Loot tier definitions
    TYPES = {
        {
            Name = "Emerald",
            Value = 1,
            Color = Color3.fromRGB(46, 204, 113),
            Material = Enum.Material.Neon,
            Size = Vector3.new(2, 2.4, 2),
            Weight = 60,
        },
        {
            Name = "Sapphire",
            Value = 2,
            Color = Color3.fromRGB(52, 152, 219),
            Material = Enum.Material.Neon,
            Size = Vector3.new(2.2, 2.6, 2.2),
            Weight = 30,
        },
        {
            Name = "Ruby",
            Value = 5,
            Color = Color3.fromRGB(231, 76, 60),
            Material = Enum.Material.Neon,
            Size = Vector3.new(2.4, 2.8, 2.4),
            Weight = 10,
        },
    } :: { LootTypeInfo },
}

return LootConfig
