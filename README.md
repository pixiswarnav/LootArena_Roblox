# Roblox Multiplayer Loot Arena

A modular, server-authoritative multiplayer combat and collection experience built in Luau for the Roblox Scripter Test Assignment.

- **Repository**: [https://github.com/pixiswarnav/LootArena_Roblox](https://github.com/pixiswarnav/LootArena_Roblox)
- **Place Files**: `LootArena.rbxl` (standard Studio place) / `LootArena.rblx` (assignment spec alias)
- **Built with**: Luau (`--!strict`), Rojo 7.x, Roblox Studio

---

## 1. Overall Approach & Architecture

The architecture prioritizes **server authority**, **multiplayer consistency**, and **clean separation of concerns**:

### System Architecture
```
LootArena/
├── default.project.json          # Rojo project mapping configuration
├── LootArena.rbxl                # Precompiled, ready-to-play place file
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Config/
│   │   │   ├── AbilityConfig.luau# Extensible ability definitions, cooldowns, stats
│   │   │   └── LootConfig.luau   # Loot tier properties, spawn rates, values
│   │   ├── Network/
│   │   │   └── Remotes.luau      # Centralized, lazy-initializing network bridge
│   │   └── Shared/
│   │       └── VisualFX.luau     # Procedural visual FX, sounds, and celebratory animations
│   ├── ServerScriptService/
│   │   ├── ServerMain.server.luau# Master server initializer
│   │   ├── ArenaManager.luau     # Procedural arena environment & spawn layouts
│   │   ├── Gem.luau              # OOP entity encapsulating 3D crystal models & lifecycle
│   │   ├── LootService.luau      # Server-authoritative loot lifecycle & anti-cheat
│   │   ├── AbilityService.luau   # Authoritative ability execution, cooldowns, damage
│   │   └── PlayerService.luau    # Leaderstats (Loot, Kills), health & respawn handling
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           ├── ClientMain.client.luau
│           └── Controllers/
│               ├── AbilityController.luau # Keybinds (Q, E/Click), client prediction
│               ├── LootController.luau    # Client-side 60 FPS crystal float/spin animation
│               └── UIController.luau      # Glassmorphic HUD (Loot, HP, Cooldown timers)
```

### Key Architectural Decisions
1. **Server Authority & Anti-Exploit**:
   - Loot spawning, pickup collection, and damage application are calculated and validated exclusively on the server.
   - Distance checks verify that the collecting player's character is within legitimate proximity of the crystal to prevent remote teleportation exploits.
   - Ability cooldowns are strictly enforced on the server, ignoring spoofed client requests.
2. **OOP Modular Entities**:
   - Loot crystals are abstracted into an Object-Oriented class (`Gem.luau`), cleanly decoupling visual creation, geometry scaling, collision listeners, and lifecycle disposal.
3. **Client Responsiveness & Optimization**:
   - Loot crystal animations (floating sine-wave bobbing and rotation) run locally on each client using `RunService.RenderStepped`. This achieves fluid 60+ FPS visuals without consuming server physics ticks or flooding network replication.
   - Immediate client-side cooldown prediction provides instant feedback while the server handles authoritative execution.
4. **Extensibility & Data-Driven Design**:
   - All abilities are defined inside `AbilityConfig.luau`. Adding a third or fourth ability (e.g. Shield, Blink, Meteor) requires only registering its stats in config and wiring a handler function, without rewriting the networking or UI layers.
   - Loot tiers (`Emerald`, `Sapphire`, `Ruby`) are data-driven with weights, values, and distinct visual materials.
5. **Procedural Arena Generation**:
   - Rather than sourcing external 3D map models and hand-placing spawn nodes manually in the Roblox Studio editor (which is time-consuming, prone to human positioning errors, and harder to version-control in Git/Rojo), the arena map, boundary walls, cover pillars, and balanced circular spawn nodes are generated procedurally by `ArenaManager.luau` on server startup.
   - This makes the place completely portable, self-contained, and deterministic without requiring manual editor setup.

### Key Assumptions & Design Choices (Per Assignment Final Note)
- **Environment & Spawning**: Assumed standard arena combat bounds (160×160 studs) with 4 symmetrical player spawns and 19 circular loot spawn nodes to prevent clustering.
- **Projectile Simulation**: Raycast-stepped simulation on the server was chosen over physical unanchored `BasePart` assemblies to eliminate client-server physics desync and network stutter.
- **Controls & Accessibility**: Mapped `[Q]` to Dash, `[E]` & `[Left Click]` to Fireball, and walk-over for Loot Collection, with click support for mobile/mouse-only accessibility.
- **Loot Respawn**: Assumed staggered respawn timers between 4–7 seconds to encourage dynamic arena movement.

---

## 2. What Was Completed

| Feature | Status | Details |
|---|---|---|
| **Multiplayer Arena** | Completed | Procedural arena floor, boundary walls with neon trims, strategic obstacle pillars, spawn locations, and atmospheric lighting presets. |
| **Loot Spawning (OOP)** | Completed | Server-authoritative spawner distributing weighted loot crystals via `Gem.luau`. |
| **Guaranteed Session Ruby** | Completed | Server spawner dynamically checks active gems to guarantee at least one rare Ruby (+5) is present in the arena at all times. |
| **Multiplayer Consistency** | Completed | Synchronized replication across all connected players. |
| **Loot Collection** | Completed | Server distance validation, atomic state protection against double pickups, and leaderstats updates. |
| **Loot Respawn System** | Completed | Automatic staggered respawn timers on vacated nodes. |
| **Primary Ability: Dash** | Completed | High-force `BodyVelocity` burst on `[Q]` overcoming ground friction, trailing ghost silhouettes, wind particles, and audio replicated to other players. |
| **Second Ability: Flame Orb (Projectile)** | Completed | Launched forward on `[E]` or `[Left Click]`, simulated with server raycasting, area-of-effect blast damage (35 HP), knockback, and explosion FX. |
| **Cooldown System** | Completed | Server-enforced cooldowns with real-time radial and numerical UI feedback on client HUD. |
| **Health & Damage System** | Completed | 100 HP system, damage attribution, floating combat damage indicators, and respawn handling. |
| **Ruby Celebration Dance** | Completed | Collecting a Ruby triggers a full-body celebratory dance animation, rainbow confetti particles, overhead banner, and victory chime, temporarily disabling dashing. |
| **Score & Kill Tracking** | Completed | Native `leaderstats` tracking both `Loot` and `Kills` per player with kill credit attribution. |
| **HUD / User Interface** | Completed | Glassmorphic HUD with loot count + bounce effect, health bar, ability slots with cooldown timers, and controls guide. |

---

## 3. What Was Not Completed / Deliberate Trade-offs

- **Hitscan vs. Physics Projectiles**: The projectile uses discrete server raycasting steps rather than physics-simulated `BasePart` assemblies. This trade-off was chosen because Roblox physics assemblies can experience desync and rubberbanding under high latency; raycasts guarantee crisp hit detection and consistent AoE detonation.
- **Client Prediction Rollback**: For abilities, client prediction is used for UI feedback and sound, while position updates rely on server physics velocity. Client-side character rollback reconciliation was omitted to maintain code readability within the test timeframe.

---

## 4. Future Improvements (With More Time)

If expanded further, the following additions would be prioritized:
1. **Loot Shop & Ability Upgrades**:
   - A shop GUI allowing players to spend collected loot to upgrade dash distance, projectile blast radius, or unlock new ability tiers.
2. **Spatial Hashing / Spatial Partitioning for Loot**:
   - Replace linear distance checks with a spatial grid or BVH structure to support thousands of active collectibles with zero overhead.
3. **Sound Asset Customization**:
   - Incorporate custom sound design and audio mixing (custom sfx for different gem tiers and ability impacts).
4. **Spectator / Match End State**:
   - Round timer, match winner announcement when a player reaches a designated loot/kill threshold, and arena map resets.

---

## 5. Setup & Run Instructions

### Option A: Direct Play in Roblox Studio (Easiest)
1. Open **`LootArena.rbxl`** directly in **Roblox Studio** (`File > Open from File...`).
2. Press **Play** (or **Test > Server and Clients** with 2 players).
3. The game, arena, UI, and all scripts are pre-compiled and ready to run immediately.

### Option B: Live Synchronization with Rojo
1. Start the Rojo sync server in the project directory:
   ```bash
   rojo serve
   ```
2. Open `LootArena.rbxl` in Roblox Studio.
3. In Roblox Studio, navigate to the **Plugins** ribbon tab and click **Rojo**.
4. Click **Connect** (default port `34872`). All scripts, configs, and controllers will synchronize live between your local filesystem and Studio.
5. In Roblox Studio:
   - Click **Play** to test solo.
   - Or select **Test > Server and Clients** (2 players) to test real-time multiplayer collection, combat, and damage replication.
