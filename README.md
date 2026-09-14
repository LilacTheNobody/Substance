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

---

### Features

- **Acrylic Glass UI** — Powered by Fluent with translucent dark purple glass styling and smooth spring animations
- **Left Control** — Press `LeftControl` at any time to toggle the menu open or closed

#### Universal
- WalkSpeed & JumpPower modifiers
- Infinite Jump & Noclip
- Server Hop, Rejoin & Copy Place ID
- Anti-AFK (idle kick prevention)

#### Murder Mystery 2
- **Master ESP Toggle** with Multi-Select role filter (Murderer, Sheriff, Innocent)
- **Dropped Gun ESP** with 3D marker
- **ESP Labels** displaying player display names and live distance
- **Combat Utilities** — Shoot Murderer, Auto Shoot, Knife Aura with distance tuning
- **Automation** — Auto Grab Dropped Gun, Auto Coin Collect

---

### Adding Games

Place your module in `modules/<gamename>.lua` returning a table with:
- `module.Name`
- `module.GameId`
- `module.Elements` (table of UI definitions)
- Optional `module.Init` and `module.BackgroundTask` hooks

Register your game's Place ID in `gameRegistry` inside `SubstanceHub.lua`.
