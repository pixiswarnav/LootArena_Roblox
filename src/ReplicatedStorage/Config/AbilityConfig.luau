--!strict
--[[
    AbilityConfig.luau
    Defines ability parameters, keybindings, cooldowns, and visual settings.
    Designed for easy modular extension of new abilities.
]]

export type AbilityDefinition = {
    Id: string,
    Name: string,
    Description: string,
    Key: Enum.KeyCode,
    Cooldown: number,
    Color: Color3,
    Stats: { [string]: any },
}

local AbilityConfig = {
    Abilities = {
        Dash = {
            Id = "Dash",
            Name = "Acrobatic Dash",
            Description = "Surges forward in current movement direction with high speed.",
            Key = Enum.KeyCode.Q,
            Cooldown = 3.0,
            Color = Color3.fromRGB(0, 210, 255),
            Stats = {
                ImpulsePower = 135, -- Studs/sec burst
                Duration = 0.24,    -- Duration of the impulse
                InvulnerabilityDuration = 0.15, -- Brief invulnerability frame
            },
        },

        Fireball = {
            Id = "Fireball",
            Name = "Flame Orb",
            Description = "Hurls an explosive magical projectile towards target direction.",
            Key = Enum.KeyCode.E,
            Cooldown = 2.5,
            Color = Color3.fromRGB(255, 120, 20),
            Stats = {
                Speed = 110,         -- Studs per second
                Damage = 35,         -- Hitpoint damage
                Lifetime = 3.0,      -- Max flight duration
                BlastRadius = 8.0,   -- AoE damage radius
                Knockback = 45,      -- Physics knockback impulse
            },
        },
    } :: { [string]: AbilityDefinition },
}

return AbilityConfig
