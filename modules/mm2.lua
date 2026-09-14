-- Substance MM2 Module
-- by substance team

local module = {}

local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local pfs = game:GetService("PathfindingService")
local vu = game:GetService("VirtualUser")
local lp = plrs.LocalPlayer

-- role cache so when the mf throws the knife we still know who they are
local murderer = nil
local sheriff = nil
local inRound = false

-- esp stuff
local highlights = {}
local billboards = {}
local gunHL = nil
local gunBB = nil

local conns = {}

-- settings
local cfg = {
	-- esp
	espMurderer = false,
	espSheriff = false,
	espInnocent = false,
	espGun = false,
	showNames = true,
	showDist = true,

	-- combat
	autoShoot = false,
	silentAim = false,
	silentFOV = 90,
	knifeAura = false,
	auraRange = 15,
	shootOffset = 3.5,

	-- util
	autoGun = false,
	autoCoins = false,
	antiAfk = false,

	-- char
	infJump = false,
	noclip = false,
	speed = 16,
	jumpPow = 50,
	hipHeight = 0,
	flingTarget = "",
}

local colors = {
	murderer = Color3.fromRGB(255, 50, 50),
	sheriff = Color3.fromRGB(50, 120, 255),
	innocent = Color3.fromRGB(50, 255, 80),
	gun = Color3.fromRGB(255, 255, 0),
}

-- =======================================
-- role finding
-- =======================================

local function findMurderer()
	for _, p in ipairs(plrs:GetPlayers()) do
		if p == lp then continue end
		local bp = p:FindFirstChild("Backpack")
		if bp and bp:FindFirstChild("Knife") then return p end
		local ch = p.Character
		if ch then
			for _, c in ipairs(ch:GetChildren()) do
				if c:IsA("Tool") and c.Name:lower():find("knife") then return p end
			end
		end
	end
	return nil
end

local function findSheriff()
	for _, p in ipairs(plrs:GetPlayers()) do
		if p == lp then continue end
		local bp = p:FindFirstChild("Backpack")
		if bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")) then return p end
		local ch = p.Character
		if ch then
			for _, c in ipairs(ch:GetChildren()) do
				if c:IsA("Tool") and (c.Name == "Gun" or c.Name == "Revolver") then return p end
			end
		end
	end
	return nil
end

local function myRole()
	local bp = lp:FindFirstChild("Backpack")
	local ch = lp.Character
	if bp and bp:FindFirstChild("Knife") then return "Murderer" end
	if ch then for _, c in ipairs(ch:GetChildren()) do
		if c:IsA("Tool") and c.Name:lower():find("knife") then return "Murderer" end
	end end
	if bp and (bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")) then return "Sheriff" end
	if ch then for _, c in ipairs(ch:GetChildren()) do
		if c:IsA("Tool") and (c.Name == "Gun" or c.Name == "Revolver") then return "Sheriff" end
	end end
	return "Innocent"
end

local function getRole(p)
	if p == lp then return myRole() end
	if p == murderer then return "Murderer" end
	if p == sheriff then return "Sheriff" end
	return "Innocent"
end

local function cacheRoles()
	local m = findMurderer()
	local s = findSheriff()
	if m then murderer = m end
	if s then sheriff = s end
end

local function resetCache()
	murderer = nil
	sheriff = nil
end

-- =======================================
-- esp
-- =======================================

local function clearESP(p)
	if highlights[p] then pcall(function() highlights[p]:Destroy() end); highlights[p] = nil end
	if billboards[p] then pcall(function() billboards[p]:Destroy() end); billboards[p] = nil end
end

local function clearAllESP()
	for p in pairs(highlights) do clearESP(p) end
end

local function clearGunESP()
	if gunHL then pcall(function() gunHL:Destroy() end); gunHL = nil end
	if gunBB then pcall(function() gunBB:Destroy() end); gunBB = nil end
end

local function shouldShow(role)
	if role == "Murderer" then return cfg.espMurderer end
	if role == "Sheriff" then return cfg.espSheriff end
	if role == "Innocent" then return cfg.espInnocent end
	return false
end

local function getColor(role)
	if role == "Murderer" then return colors.murderer end
	if role == "Sheriff" then return colors.sheriff end
	return colors.innocent
end

local function doESP(p)
	if p == lp then return end
	local ch = p.Character
	if not ch then clearESP(p); return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local head = ch:FindFirstChild("Head")
	if not hrp or not head then clearESP(p); return end

	local role = getRole(p)
	if not shouldShow(role) then clearESP(p); return end
	local col = getColor(role)

	-- highlight
	if not highlights[p] or not highlights[p].Parent then
		clearESP(p)
		local hl = Instance.new("Highlight")
		hl.Name = "SubESP"
		hl.FillColor = col
		hl.FillTransparency = 0.5
		hl.OutlineColor = col
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = ch
		hl.Parent = ch
		highlights[p] = hl
	else
		highlights[p].FillColor = col
		highlights[p].OutlineColor = col
		highlights[p].Adornee = ch
	end

	-- billboard
	if not billboards[p] or not billboards[p].Parent then
		local bb = Instance.new("BillboardGui")
		bb.Name = "SubESPLabel"
		bb.Adornee = head
		bb.Size = UDim2.fromOffset(200, 50)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.Parent = ch

		local rl = Instance.new("TextLabel")
		rl.Name = "Role"
		rl.Size = UDim2.new(1, 0, 0.5, 0)
		rl.BackgroundTransparency = 1
		rl.Font = Enum.Font.GothamBold
		rl.TextSize = 14
		rl.TextColor3 = col
		rl.TextStrokeTransparency = 0.3
		rl.TextStrokeColor3 = Color3.new(0, 0, 0)
		rl.Text = "【" .. role:upper() .. "】"
		rl.Parent = bb

		local nl = Instance.new("TextLabel")
		nl.Name = "Info"
		nl.Size = UDim2.new(1, 0, 0.5, 0)
		nl.Position = UDim2.new(0, 0, 0.5, 0)
		nl.BackgroundTransparency = 1
		nl.Font = Enum.Font.Gotham
		nl.TextSize = 12
		nl.TextColor3 = Color3.fromRGB(220, 220, 220)
		nl.TextStrokeTransparency = 0.3
		nl.TextStrokeColor3 = Color3.new(0, 0, 0)
		nl.Text = ""
		nl.Parent = bb

		billboards[p] = bb
	end

	-- update labels
	local bb = billboards[p]
	if bb then
		local rl = bb:FindFirstChild("Role")
		local nl = bb:FindFirstChild("Info")
		if rl then rl.Text = "【" .. role:upper() .. "】"; rl.TextColor3 = col end
		if nl then
			local txt = {}
			if cfg.showNames then table.insert(txt, p.DisplayName) end
			if cfg.showDist then
				local myc = lp.Character
				if myc and myc:FindFirstChild("HumanoidRootPart") then
					local d = math.floor((myc.HumanoidRootPart.Position - hrp.Position).Magnitude)
					table.insert(txt, "[" .. d .. "m]")
				end
			end
			nl.Text = table.concat(txt, " ")
		end
	end
end

local function doGunESP()
	local gd = workspace:FindFirstChild("GunDrop")
	if not gd or not cfg.espGun then clearGunESP(); return end

	if not gunHL or not gunHL.Parent then
		clearGunESP()
		local hl = Instance.new("Highlight")
		hl.Name = "SubGunESP"
		hl.FillColor = colors.gun
		hl.FillTransparency = 0.3
		hl.OutlineColor = colors.gun
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Adornee = gd
		hl.Parent = gd
		gunHL = hl

		local bb = Instance.new("BillboardGui")
		bb.Name = "SubGunLabel"
		bb.Size = UDim2.fromOffset(150, 30)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = gd
		bb.Parent = gd

		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 1, 0)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextSize = 14
		l.TextColor3 = colors.gun
		l.TextStrokeTransparency = 0.3
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.Text = "🔫 DROPPED GUN"
		l.Parent = bb
		gunBB = bb
	end
end

-- =======================================
-- combat
-- =======================================

local function shoot(pos)
	local ch = lp.Character
	if not ch then return false end

	-- equip gun
	if not ch:FindFirstChild("Gun") then
		local bp = lp:FindFirstChild("Backpack")
		if bp and bp:FindFirstChild("Gun") then
			local hum = ch:FindFirstChild("Humanoid")
			if hum then hum:EquipTool(bp.Gun) end
			task.wait(0.1)
		else
			return false
		end
	end

	local gun = ch:FindFirstChild("Gun")
	if not gun then return false end
	local ks = gun:FindFirstChild("KnifeServer")
	if not ks then return false end
	local sg = ks:FindFirstChild("ShootGun")
	if not sg then return false end

	pcall(function() sg:InvokeServer(1, pos, "AH") end)
	return true
end

local function shootMurderer()
	if not murderer then return false end
	local ch = murderer.Character
	if not ch then return false end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local hum = ch:FindFirstChild("Humanoid")
	if not hrp or not hum then return false end
	return shoot(hrp.Position + hum.MoveDirection * cfg.shootOffset)
end

local function canSee(targetPos)
	local ch = lp.Character
	if not ch then return false end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {ch}
	local hit = workspace:Raycast(hrp.Position, targetPos - hrp.Position, params)

	if not hit then return true end
	for _, p in ipairs(plrs:GetPlayers()) do
		if p.Character and hit.Instance:IsDescendantOf(p.Character) then return true end
	end
	return false
end

-- =======================================
-- round detection
-- =======================================

local function roundStart(api)
	inRound = true
	resetCache()
	if api then api.Notify({ Title = "MM2", Description = "Round started, scanning roles...", Duration = 3 }) end

	-- wait for tools to show up
	local tries = 0
	repeat
		task.wait(1)
		cacheRoles()
		tries = tries + 1
	until (murderer and sheriff) or tries > 15

	if murderer and api then
		api.Notify({ Title = "🔴 Murderer", Description = murderer.DisplayName, Duration = 5, Color = colors.murderer })
	end
	if sheriff and api then
		api.Notify({ Title = "🔵 Sheriff", Description = sheriff.DisplayName, Duration = 5, Color = colors.sheriff })
	end
end

local function roundEnd(api)
	inRound = false
	resetCache()
	clearAllESP()
	clearGunESP()
	if api then api.Notify({ Title = "MM2", Description = "Round ended.", Duration = 2 }) end
end

-- =======================================
-- module definition
-- =======================================

module.Name = "MM2"
module.GameId = 142823291
module.GameName = "Murder Mystery 2"
module.Author = "Substance"
module.Version = "2.0"
module.Icon = "rbxassetid://7733717504"

module.Elements = {
	-- esp
	{ Type = "Section", Name = "ESP" },

	{ Type = "Toggle", Name = "Enable ESP", Default = false,
		Callback = function(v)
			cfg.espMurderer = v
			cfg.espSheriff = v
			cfg.espInnocent = v
			if not v then clearAllESP() end
		end },

	{ Type = "Dropdown", Name = "Show Roles", Options = { "All", "Murderer Only", "Sheriff Only", "Murderer + Sheriff", "Innocent Only" }, Default = "Murderer + Sheriff",
		Callback = function(v)
			-- reset all
			cfg.espMurderer = false
			cfg.espSheriff = false
			cfg.espInnocent = false

			if v == "All" then
				cfg.espMurderer = true; cfg.espSheriff = true; cfg.espInnocent = true
			elseif v == "Murderer Only" then
				cfg.espMurderer = true
			elseif v == "Sheriff Only" then
				cfg.espSheriff = true
			elseif v == "Murderer + Sheriff" then
				cfg.espMurderer = true; cfg.espSheriff = true
			elseif v == "Innocent Only" then
				cfg.espInnocent = true
			end

			-- clear esp for roles that got turned off
			for p in pairs(highlights) do
				if not shouldShow(getRole(p)) then clearESP(p) end
			end
		end },

	{ Type = "Toggle", Name = "Dropped Gun ESP", Default = false,
		Callback = function(v) cfg.espGun = v; if not v then clearGunESP() end end },

	{ Type = "Toggle", Name = "Show Names", Default = true,
		Callback = function(v) cfg.showNames = v end },

	{ Type = "Toggle", Name = "Show Distance", Default = true,
		Callback = function(v) cfg.showDist = v end },

	{ Type = "Separator" },

	-- combat
	{ Type = "Section", Name = "Combat" },

	{ Type = "Button", Name = "Shoot Murderer",
		Callback = function()
			local hasGun = lp.Backpack:FindFirstChild("Gun") or (lp.Character and lp.Character:FindFirstChild("Gun"))
			if not hasGun then return end
			if not murderer then return end
			shootMurderer()
		end },

	{ Type = "Toggle", Name = "Auto Shoot Murderer", Default = false,
		Callback = function(v) cfg.autoShoot = v end },

	{ Type = "Slider", Name = "Shoot Offset", Min = 0, Max = 10, Default = 4,
		Callback = function(v) cfg.shootOffset = v end },

	{ Type = "Toggle", Name = "Knife Aura", Default = false,
		Callback = function(v) cfg.knifeAura = v end },

	{ Type = "Slider", Name = "Aura Range", Min = 5, Max = 50, Default = 15,
		Callback = function(v) cfg.auraRange = v end },

	{ Type = "Label", Text = "Knife aura only works if you're the murderer" },

	{ Type = "Separator" },

	-- utility
	{ Type = "Section", Name = "Utility" },

	{ Type = "Toggle", Name = "Auto Pick Up Gun", Default = false,
		Callback = function(v) cfg.autoGun = v end },

	{ Type = "Toggle", Name = "Auto Collect Coins", Default = false,
		Callback = function(v) cfg.autoCoins = v end },

	{ Type = "Button", Name = "Fast-Move to Gun",
		Callback = function()
			local gd = workspace:FindFirstChild("GunDrop")
			if not gd then return end
			local ch = lp.Character
			if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end

			local path = pfs:CreatePath({
				AgentRadius = 3,
				AgentHeight = ch:GetExtentsSize().Y,
				AgentCanJump = true,
			})

			local ok = pcall(function()
				path:ComputeAsync(ch.PrimaryPart.Position, gd:GetPivot().Position)
			end)

			if ok and path.Status == Enum.PathStatus.Success then
				for _, wp in ipairs(path:GetWaypoints()) do
					task.wait(0.01)
					ts:Create(ch.HumanoidRootPart, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
						CFrame = CFrame.new(wp.Position + Vector3.new(0, 3, 0))
					}):Play()
				end
			end
		end },

	{ Type = "Toggle", Name = "Anti AFK", Default = false,
		Callback = function(v) cfg.antiAfk = v end },

	{ Type = "Separator" },

	-- character
	{ Type = "Section", Name = "Character" },

	{ Type = "Slider", Name = "Walk Speed", Min = 16, Max = 500, Default = 16,
		Callback = function(v) cfg.speed = v; pcall(function() lp.Character.Humanoid.WalkSpeed = v end) end },

	{ Type = "Slider", Name = "Jump Power", Min = 50, Max = 500, Default = 50,
		Callback = function(v) cfg.jumpPow = v; pcall(function() lp.Character.Humanoid.JumpPower = v end) end },

	{ Type = "Slider", Name = "Hip Height", Min = 0, Max = 100, Default = 0,
		Callback = function(v) cfg.hipHeight = v; pcall(function() lp.Character.Humanoid.HipHeight = v end) end },

	{ Type = "Toggle", Name = "Infinite Jump", Default = false,
		Callback = function(v) cfg.infJump = v end },

	{ Type = "Toggle", Name = "Noclip", Default = false,
		Callback = function(v) cfg.noclip = v end },

	{ Type = "Separator" },

	-- fling
	{ Type = "Section", Name = "Fling" },

	{ Type = "Textbox", Name = "Target", Placeholder = "username...",
		Callback = function(v) cfg.flingTarget = v end },

	{ Type = "Button", Name = "Fling Target",
		Callback = function()
			local target = plrs:FindFirstChild(cfg.flingTarget)
			if not target or not target.Character then return end
			local thrp = target.Character:FindFirstChild("HumanoidRootPart")
			if not thrp then return end
			local ch = lp.Character
			if not ch then return end
			local myhrp = ch:FindFirstChild("HumanoidRootPart")
			if not myhrp then return end

			local oldCF = myhrp.CFrame
			local vel = Instance.new("BodyAngularVelocity")
			vel.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			vel.AngularVelocity = Vector3.new(0, 9999, 0)
			vel.Parent = myhrp

			for i = 1, 20 do myhrp.CFrame = thrp.CFrame; task.wait(0.05) end
			vel:Destroy()
			myhrp.CFrame = oldCF
		end },

	{ Type = "Button", Name = "Fling Murderer",
		Callback = function()
			if not murderer or not murderer.Character then return end
			local thrp = murderer.Character:FindFirstChild("HumanoidRootPart")
			if not thrp then return end
			local ch = lp.Character
			if not ch then return end
			local myhrp = ch:FindFirstChild("HumanoidRootPart")
			if not myhrp then return end

			local oldCF = myhrp.CFrame
			local vel = Instance.new("BodyAngularVelocity")
			vel.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			vel.AngularVelocity = Vector3.new(0, 9999, 0)
			vel.Parent = myhrp

			for i = 1, 20 do myhrp.CFrame = thrp.CFrame; task.wait(0.05) end
			vel:Destroy()
			myhrp.CFrame = oldCF
		end },

	{ Type = "Separator" },
	{ Type = "Section", Name = "Info" },
	{ Type = "Label", Text = "Roles are cached at round start so knife throws don't break esp" },
	{ Type = "Label", Text = "Red = Murderer | Blue = Sheriff | Green = Innocent | Yellow = Gun" },
	{ Type = "Label", Text = "Combat stuff can get you caught, use wisely" },
}

-- =======================================
-- init
-- =======================================

module.Init = function(api)
	api.Notify({ Title = "MM2", Description = "Module loaded, waiting for round...", Duration = 4, Color = Color3.fromRGB(138, 43, 226) })

	-- round detection
	table.insert(conns, workspace.ChildAdded:Connect(function(ch)
		if ch.Name == "Normal" then task.wait(0.5); roundStart(api) end
		if ch.Name == "GunDrop" then
			if cfg.espGun then doGunESP() end
			if cfg.autoGun then api.Notify({ Title = "Gun", Description = "Gun dropped! picking up...", Duration = 2 }) end
		end
	end))

	table.insert(conns, workspace.ChildRemoved:Connect(function(ch)
		if ch.Name == "Normal" then roundEnd(api) end
		if ch.Name == "GunDrop" then clearGunESP() end
	end))

	-- cleanup on leave
	table.insert(conns, plrs.PlayerRemoving:Connect(function(p)
		clearESP(p)
		if p == murderer then murderer = nil end
		if p == sheriff then sheriff = nil end
	end))

	-- re-apply esp on respawn
	for _, p in ipairs(plrs:GetPlayers()) do
		if p ~= lp then
			table.insert(conns, p.CharacterAdded:Connect(function()
				task.wait(0.5)
				if inRound then doESP(p) end
			end))
		end
	end

	table.insert(conns, plrs.PlayerAdded:Connect(function(p)
		table.insert(conns, p.CharacterAdded:Connect(function()
			task.wait(0.5)
			if inRound then doESP(p) end
		end))
	end))

	-- infinite jump
	table.insert(conns, uis.JumpRequest:Connect(function()
		if cfg.infJump then
			pcall(function() lp.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
		end
	end))

	-- noclip
	table.insert(conns, rs.Stepped:Connect(function()
		if cfg.noclip and lp.Character then
			pcall(function()
				for _, part in ipairs(lp.Character:GetDescendants()) do
					if part:IsA("BasePart") then part.CanCollide = false end
				end
			end)
		end
	end))

	-- anti afk
	table.insert(conns, lp.Idled:Connect(function()
		if cfg.antiAfk then
			pcall(function()
				vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
				task.wait(0.1)
				vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			end)
		end
	end))

	-- check if already in round
	if workspace:FindFirstChild("Normal") then
		task.spawn(function() roundStart(api) end)
	end
end

-- =======================================
-- background loop
-- =======================================

module.BackgroundTask = function(api)
	while api.Running do
		if inRound then
			cacheRoles()

			-- update esp
			for _, p in ipairs(plrs:GetPlayers()) do
				if p ~= lp then doESP(p) end
			end
			doGunESP()

			-- auto shoot
			if cfg.autoShoot and murderer then
				local hasGun = lp.Backpack:FindFirstChild("Gun") or (lp.Character and lp.Character:FindFirstChild("Gun"))
				if hasGun and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
					if canSee(murderer.Character.HumanoidRootPart.Position) then
						shootMurderer()
					end
				end
			end

			-- knife aura
			if cfg.knifeAura and myRole() == "Murderer" then
				local ch = lp.Character
				if ch and ch:FindFirstChild("HumanoidRootPart") then
					for _, p in ipairs(plrs:GetPlayers()) do
						if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
							local dist = (ch.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
							if dist <= cfg.auraRange then
								pcall(function()
									if not ch:FindFirstChild("Knife") then
										if lp.Backpack:FindFirstChild("Knife") then
											ch.Humanoid:EquipTool(lp.Backpack.Knife)
										end
									end
									if ch:FindFirstChild("Knife") then
										local old = ch.HumanoidRootPart.CFrame
										ch.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame
										task.wait(0.05)
										ch.Knife:Activate()
										task.wait(0.05)
										ch.HumanoidRootPart.CFrame = old
									end
								end)
							end
						end
					end
				end
			end

			-- auto pickup gun
			if cfg.autoGun then
				local gd = workspace:FindFirstChild("GunDrop")
				if gd then
					local ch = lp.Character
					if ch and ch:FindFirstChild("HumanoidRootPart") then
						local dist = (ch.HumanoidRootPart.Position - gd:GetPivot().Position).Magnitude
						if dist > 15 then
							ts:Create(ch.HumanoidRootPart, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
								CFrame = CFrame.new(gd:GetPivot().Position + Vector3.new(0, 3, 0))
							}):Play()
						end
					end
				end
			end

			-- auto coins
			if cfg.autoCoins then
				pcall(function()
					local normal = workspace:FindFirstChild("Normal")
					if normal then
						local cc = normal:FindFirstChild("CoinContainer")
						if cc then
							local coin = cc:FindFirstChild("Coin_Server")
							if coin then
								local ch = lp.Character
								if ch and ch:FindFirstChild("HumanoidRootPart") then
									ch.HumanoidRootPart.CFrame = CFrame.new(coin:GetPivot().Position + Vector3.new(0, 2, 0))
								end
							end
						end
					end
				end)
			end

			-- reapply char mods
			pcall(function()
				if lp.Character and lp.Character:FindFirstChild("Humanoid") then
					local hum = lp.Character.Humanoid
					if cfg.speed ~= 16 then hum.WalkSpeed = cfg.speed end
					if cfg.jumpPow ~= 50 then hum.JumpPower = cfg.jumpPow end
					if cfg.hipHeight ~= 0 then hum.HipHeight = cfg.hipHeight end
				end
			end)
		end

		task.wait(0.3)
	end
end

-- =======================================
-- cleanup
-- =======================================

module.Cleanup = function()
	clearAllESP()
	clearGunESP()
	resetCache()
	inRound = false

	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}

	pcall(function()
		if lp.Character and lp.Character:FindFirstChild("Humanoid") then
			lp.Character.Humanoid.WalkSpeed = 16
			lp.Character.Humanoid.JumpPower = 50
			lp.Character.Humanoid.HipHeight = 0
		end
	end)
end

return module
