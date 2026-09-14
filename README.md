<div align="center">

# Substance

**A sleek acrylic glass script hub for Roblox**

![Lua](https://img.shields.io/badge/Language-Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![Roblox](https://img.shields.io/badge/Platform-Roblox-000000?style=for-the-badge&logo=roblox&logoColor=white)
![UI](https://img.shields.io/badge/Theme-Amethyst%20Glass-8A2BE2?style=for-the-badge)
![License](https://img.shields.io/badge/License-GPL%20v3-blue?style=for-the-badge)

</div>

---

### Quick Start

Execute this in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceHub.lua"))()
```

Or run via the loader:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceLoader.lua"))()
```

**Key:** `releasehellyeah`  
**Discord:** `https://discord.gg/substance`

---

### Features

- **Acrylic Glass UI** — Fluent UI window with frosted dark purple glass styling and spring animations
- **Fluent Key System** — Key verification with Discord invite button
- **Left Control** — Press `LeftControl` at any time to toggle menu visibility

#### Universal
- **Safe Noclip** — Walk through walls and doors without falling through the floor
- **Persistent Speed & Jump** — Never gets cancelled by tool equip or attack animations
- **Anti Fling** — Immune to physics pushes and player collision flinging
- **Fling Player** — Select any target player and launch them with high-torque physics
- **Infinite Jump**
- **Server Hop, Rejoin & Copy Place ID**
- **Anti-AFK** — Prevents idle disconnects

#### Murder Mystery 2
- **Accurate Role Detection** — Instant tracking of Murderer and Sheriff across Backpack, Character, and holstered weapons
- **Multi-Round Persistence** — ESP and combat loops continue across round resets and respawns
- **Master ESP Toggle** with Multi-Select filter (`Murderer`, `Sheriff`, `Innocent`)
- **Visual ESP** — Clean AlwaysOnTop highlights with Gotham bold role tags and live distance meters
- **Dropped Gun ESP** — Gold highlight with 3D distance label
- **Combat** — Shoot Murderer (with target velocity prediction), Auto Shoot, Kill All, Auto Kill All, Knife Aura with distance slider
- **Automation** — Auto Grab Dropped Gun, Auto Coin Farm

---

### Adding Games

Place your module in `modules/<gamename>.lua` returning a table with:
- `module.Name`
- `module.GameId`
- `module.Elements` (table of UI definitions)
- Optional `module.Init` and `module.BackgroundTask` hooks

Register your game's Place ID in `gameRegistry` inside `SubstanceHub.lua`.
