-- mm2 module
-- substance

local module = {}

local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local vu = game:GetService("VirtualUser")
local lp = plrs.LocalPlayer

-- settings
local cfg = {
	esp = false,
	roles = {
		Murderer = true,
		Sheriff = true,
		Innocent = false,
	},
	gunEsp = true,
	showNames = true,
	showDist = true,

	-- combat
	autoShoot = false,
	silentAim = false,
	knifeAura = false,
	auraRange = 15,
	shootOffset = 3.5,

	-- util
	autoGun = false,
	autoCoins = false,
	coinLimit = 40,
	antiAfk = true,

	-- character
	infJump = false,
	noclip = false,
	speed = 16,
	jumpPow = 50,
}

local colors = {
	Murderer = Color3.fromRGB(255, 40, 40),
	Sheriff = Color3.fromRGB(40, 130, 255),
	Innocent = Color3.fromRGB(40, 220, 80),
	Gun = Color3.fromRGB(255, 215, 0),
}

local cachedRoles = {}
local highlights = {}
local billboards = {}
local gunHL = nil
local gunBB = nil
local conns = {}

-- role helpers
local function isKnife(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local n = tool.Name:lower()
	return n == "knife" or n:find("knife") ~= nil or tool:FindFirstChild("KnifeScript") ~= nil
end

local function isGun(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local n = tool.Name:lower()
	return n == "gun" or n == "revolver" or n:find("gun") ~= nil or tool:FindFirstChild("GunScript") ~= nil
end

local function scanPlayerRole(p)
	if not p or not p.Parent then return nil end

	-- check character
	if p.Character then
		for _, item in ipairs(p.Character:GetChildren()) do
			if isKnife(item) then return "Murderer" end
			if isGun(item) then return "Sheriff" end
		end
	end

	-- check backpack
	local bp = p:FindFirstChild("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if isKnife(item) then return "Murderer" end
			if isGun(item) then return "Sheriff" end
		end
	end

	return nil
end

local function getRole(p)
	if p == lp then
		local r = scanPlayerRole(lp)
		return r or "Innocent"
	end

	-- check live inventory first
	local detected = scanPlayerRole(p)
	if detected then
		cachedRoles[p] = detected
		return detected
	end

	-- if previously marked murderer or sheriff keep it until respawn
	if cachedRoles[p] then
		return cachedRoles[p]
	end

	return "Innocent"
end

local function getMurderer()
	for _, p in ipairs(plrs:GetPlayers()) do
		if getRole(p) == "Murderer" then
			return p
		end
	end
	return nil
end

local function getSheriff()
	for _, p in ipairs(plrs:GetPlayers()) do
		if getRole(p) == "Sheriff" then
			return p
		end
	end
	return nil
end

-- esp logic
local function clearPlayerESP(p)
	if highlights[p] then
		pcall(function() highlights[p]:Destroy() end)
		highlights[p] = nil
	end
	if billboards[p] then
		pcall(function() billboards[p]:Destroy() end)
		billboards[p] = nil
	end
end

local function clearAllESP()
	for p in pairs(highlights) do
		clearPlayerESP(p)
	end
	for p in pairs(billboards) do
		clearPlayerESP(p)
	end
end

local function clearGunESP()
	if gunHL then
		pcall(function() gunHL:Destroy() end)
		gunHL = nil
	end
	if gunBB then
		pcall(function() gunBB:Destroy() end)
		gunBB = nil
	end
end

local function updatePlayerESP(p)
	if p == lp then return end

	local ch = p.Character
	if not ch or not ch.Parent then
		clearPlayerESP(p)
		return
	end

	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local head = ch:FindFirstChild("Head")
	local hum = ch:FindFirstChild("Humanoid")

	if not hrp or not head or (hum and hum.Health <= 0) then
		clearPlayerESP(p)
		return
	end

	if not cfg.esp then
		clearPlayerESP(p)
		return
	end

	local role = getRole(p)
	if not cfg.roles[role] then
		clearPlayerESP(p)
		return
	end

	local col = colors[role] or colors.Innocent

	-- highlight
	local hl = highlights[p]
	if not hl or hl.Parent ~= ch then
		if hl then pcall(function() hl:Destroy() end) end
		hl = Instance.new("Highlight")
		hl.Name = "SubESP"
		hl.Adornee = ch
		hl.FillColor = col
		hl.FillTransparency = 0.5
		hl.OutlineColor = col
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = ch
		highlights[p] = hl
	else
		hl.FillColor = col
		hl.OutlineColor = col
	end

	-- billboard
	local bb = billboards[p]
	if not bb or bb.Parent ~= head then
		if bb then pcall(function() bb:Destroy() end) end
		bb = Instance.new("BillboardGui")
		bb.Name = "SubESPLabel"
		bb.Adornee = head
		bb.Size = UDim2.fromOffset(160, 36)
		bb.StudsOffset = Vector3.new(0, 2.5, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 600

		local rLabel = Instance.new("TextLabel")
		rLabel.Name = "Role"
		rLabel.Size = UDim2.new(1, 0, 0.5, 0)
		rLabel.BackgroundTransparency = 1
		rLabel.Font = Enum.Font.GothamBold
		rLabel.TextSize = 13
		rLabel.TextColor3 = col
		rLabel.TextStrokeTransparency = 0.2
		rLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		rLabel.Parent = bb

		local iLabel = Instance.new("TextLabel")
		iLabel.Name = "Info"
		iLabel.Size = UDim2.new(1, 0, 0.5, 0)
		iLabel.Position = UDim2.new(0, 0, 0.5, 0)
		iLabel.BackgroundTransparency = 1
		iLabel.Font = Enum.Font.Gotham
		iLabel.TextSize = 11
		iLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
		iLabel.TextStrokeTransparency = 0.2
		iLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		iLabel.Parent = bb

		bb.Parent = head
		billboards[p] = bb
	end

	local rl = bb:FindFirstChild("Role")
	local il = bb:FindFirstChild("Info")
	if rl then
		rl.Text = "[" .. role:upper() .. "]"
		rl.TextColor3 = col
	end
	if il then
		local parts = {}
		if cfg.showNames then
			table.insert(parts, p.DisplayName)
		end
		if cfg.showDist and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
			local dist = math.floor((lp.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
			table.insert(parts, tostring(dist) .. "m")
		end
		il.Text = table.concat(parts, " - ")
	end
end

local function updateGunESP()
	local gd = workspace:FindFirstChild("GunDrop")
	if not gd or not cfg.gunEsp then
		clearGunESP()
		return
	end

	if not gunHL or gunHL.Parent ~= gd then
		if gunHL then pcall(function() gunHL:Destroy() end) end
		local hl = Instance.new("Highlight")
		hl.Name = "SubGunESP"
		hl.Adornee = gd
		hl.FillColor = colors.Gun
		hl.FillTransparency = 0.3
		hl.OutlineColor = colors.Gun
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = gd
		gunHL = hl
	end

	if not gunBB or gunBB.Parent ~= gd then
		if gunBB then pcall(function() gunBB:Destroy() end) end
		local bb = Instance.new("BillboardGui")
		bb.Name = "SubGunLabel"
		bb.Adornee = gd
		bb.Size = UDim2.fromOffset(130, 24)
		bb.StudsOffset = Vector3.new(0, 2, 0)
		bb.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextColor3 = colors.Gun
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.Text = "DROPPED GUN"
		label.Parent = bb

		bb.Parent = gd
		gunBB = bb
	end
end

-- combat
local function shootAt(pos)
	local ch = lp.Character
	if not ch then return false end

	local gun = ch:FindFirstChild("Gun") or ch:FindFirstChild("Revolver")
	if not gun then
		local bp = lp:FindFirstChild("Backpack")
		if bp then
			local bg = bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")
			if bg then
				local hum = ch:FindFirstChild("Humanoid")
				if hum then hum:EquipTool(bg) end
				task.wait(0.1)
				gun = ch:FindFirstChild("Gun") or ch:FindFirstChild("Revolver")
			end
		end
	end

	if not gun then return false end

	local ks = gun:FindFirstChild("KnifeServer")
	if ks then
		local sg = ks:FindFirstChild("ShootGun")
		if sg then
			pcall(function() sg:InvokeServer(1, pos, "AH") end)
			return true
		end
	end

	local shootRemote = gun:FindFirstChild("Shoot") or gun:FindFirstChild("ShootGun")
	if shootRemote then
		pcall(function()
			if shootRemote:IsA("RemoteFunction") then
				shootRemote:InvokeServer(pos)
			else
				shootRemote:FireServer(pos)
			end
		end)
		return true
	end

	return false
end

local function shootMurderer()
	local m = getMurderer()
	if not m or not m.Character then return false end
	local hrp = m.Character:FindFirstChild("HumanoidRootPart")
	local hum = m.Character:FindFirstChild("Humanoid")
	if not hrp or not hum then return false end

	local targetPos = hrp.Position + (hum.MoveDirection * cfg.shootOffset)
	return shootAt(targetPos)
end

-- module metadata
module.Name = "MM2"
module.GameId = 142823291
module.GameName = "Murder Mystery 2"
module.Author = "Substance"
module.Version = "2.1"
module.Icon = "crosshair"

-- ui elements
module.Elements = {
	{ Type = "Section", Name = "ESP" },

	{
		Type = "Toggle",
		Name = "Enable ESP",
		Default = false,
		Callback = function(v)
			cfg.esp = v
			if not v then
				clearAllESP()
			end
		end,
	},

	{
		Type = "Dropdown",
		Name = "ESP Roles",
		Multi = true,
		Values = { "Murderer", "Sheriff", "Innocent" },
		Default = { "Murderer", "Sheriff" },
		Callback = function(v)
			cfg.roles = {
				Murderer = false,
				Sheriff = false,
				Innocent = false,
			}
			if type(v) == "table" then
				for role, active in pairs(v) do
					if active then cfg.roles[role] = true end
				end
			end
			-- clear esp for unselected
			for p in pairs(highlights) do
				local r = getRole(p)
				if not cfg.roles[r] then
					clearPlayerESP(p)
				end
			end
		end,
	},

	{
		Type = "Toggle",
		Name = "Dropped Gun ESP",
		Default = true,
		Callback = function(v)
			cfg.gunEsp = v
			if not v then clearGunESP() end
		end,
	},

	{
		Type = "Toggle",
		Name = "Show Names",
		Default = true,
		Callback = function(v)
			cfg.showNames = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Show Distance",
		Default = true,
		Callback = function(v)
			cfg.showDist = v
		end,
	},

	{ Type = "Section", Name = "Combat" },

	{
		Type = "Button",
		Name = "Shoot Murderer",
		Callback = function()
			shootMurderer()
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Shoot Murderer",
		Default = false,
		Callback = function(v)
			cfg.autoShoot = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Knife Aura",
		Default = false,
		Callback = function(v)
			cfg.knifeAura = v
		end,
	},

	{
		Type = "Slider",
		Name = "Aura Distance",
		Min = 5,
		Max = 30,
		Default = 15,
		Rounding = 1,
		Callback = function(v)
			cfg.auraRange = v
		end,
	},

	{ Type = "Section", Name = "Utility" },

	{
		Type = "Toggle",
		Name = "Auto Grab Gun",
		Default = false,
		Callback = function(v)
			cfg.autoGun = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Coin Farm",
		Default = false,
		Callback = function(v)
			cfg.autoCoins = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Anti AFK",
		Default = true,
		Callback = function(v)
			cfg.antiAfk = v
		end,
	},

	{ Type = "Section", Name = "Movement" },

	{
		Type = "Slider",
		Name = "WalkSpeed",
		Min = 16,
		Max = 120,
		Default = 16,
		Rounding = 1,
		Callback = function(v)
			cfg.speed = v
			pcall(function()
				if lp.Character and lp.Character:FindFirstChild("Humanoid") then
					lp.Character.Humanoid.WalkSpeed = v
				end
			end)
		end,
	},

	{
		Type = "Slider",
		Name = "JumpPower",
		Min = 50,
		Max = 200,
		Default = 50,
		Rounding = 1,
		Callback = function(v)
			cfg.jumpPow = v
			pcall(function()
				if lp.Character and lp.Character:FindFirstChild("Humanoid") then
					lp.Character.Humanoid.JumpPower = v
				end
			end)
		end,
	},

	{
		Type = "Toggle",
		Name = "Infinite Jump",
		Default = false,
		Callback = function(v)
			cfg.infJump = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Noclip",
		Default = false,
		Callback = function(v)
			cfg.noclip = v
		end,
	},
}

-- init hooks
module.Init = function(api)
	-- character respawn role reset
	local function hookPlayer(p)
		table.insert(conns, p.CharacterAdded:Connect(function()
			cachedRoles[p] = nil
			clearPlayerESP(p)
			task.wait(0.5)
			if cfg.esp then updatePlayerESP(p) end
		end))

		-- detect tool added to backpack
		local bp = p:FindFirstChild("Backpack")
		if bp then
			table.insert(conns, bp.ChildAdded:Connect(function(item)
				if isKnife(item) then
					cachedRoles[p] = "Murderer"
				elseif isGun(item) then
					cachedRoles[p] = "Sheriff"
				end
			end))
		end
	end

	for _, p in ipairs(plrs:GetPlayers()) do
		hookPlayer(p)
	end

	table.insert(conns, plrs.PlayerAdded:Connect(hookPlayer))

	table.insert(conns, plrs.PlayerRemoving:Connect(function(p)
		cachedRoles[p] = nil
		clearPlayerESP(p)
	end))

	-- jump request for infinite jump
	table.insert(conns, uis.JumpRequest:Connect(function()
		if cfg.infJump and lp.Character then
			pcall(function()
				lp.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end)
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

	-- dropped gun detector
	table.insert(conns, workspace.ChildAdded:Connect(function(child)
		if child.Name == "GunDrop" then
			task.wait(0.1)
			if cfg.gunEsp then updateGunESP() end
			if cfg.autoGun then
				task.spawn(function()
					local ch = lp.Character
					if ch and ch:FindFirstChild("HumanoidRootPart") then
						local oldCf = ch.HumanoidRootPart.CFrame
						local pos = child:GetPivot().Position
						ch.HumanoidRootPart.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
						task.wait(0.2)
						ch.HumanoidRootPart.CFrame = oldCf
					end
				end)
			end
		end
	end))

	table.insert(conns, workspace.ChildRemoved:Connect(function(child)
		if child.Name == "GunDrop" then
			clearGunESP()
		end
	end))
end

-- background loop
module.BackgroundTask = function(api)
	while api.Running do
		-- esp loop
		if cfg.esp then
			for _, p in ipairs(plrs:GetPlayers()) do
				if p ~= lp then
					updatePlayerESP(p)
				end
			end
		end

		-- gun esp
		if cfg.gunEsp then
			updateGunESP()
		end

		-- auto shoot
		if cfg.autoShoot then
			local m = getMurderer()
			if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
				local hasGun = lp.Backpack:FindFirstChild("Gun") or (lp.Character and lp.Character:FindFirstChild("Gun"))
				if hasGun then
					shootMurderer()
				end
			end
		end

		-- knife aura
		if cfg.knifeAura and getRole(lp) == "Murderer" then
			local ch = lp.Character
			if ch and ch:FindFirstChild("HumanoidRootPart") then
				local knife = ch:FindFirstChild("Knife") or lp.Backpack:FindFirstChild("Knife")
				if knife then
					for _, p in ipairs(plrs:GetPlayers()) do
						if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
							local dist = (ch.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
							if dist <= cfg.auraRange then
								pcall(function()
									if knife.Parent == lp.Backpack then
										ch.Humanoid:EquipTool(knife)
									end
									knife:Activate()
								end)
							end
						end
					end
				end
			end
		end

		-- auto coins
		if cfg.autoCoins and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
			pcall(function()
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj.Name == "Coin_Server" or obj.Name == "Coin" then
						if obj:IsA("BasePart") or obj:IsA("Model") then
							local coinPos = obj:GetPivot().Position
							lp.Character.HumanoidRootPart.CFrame = CFrame.new(coinPos + Vector3.new(0, 1.5, 0))
							task.wait(0.3)
							break
						end
					end
				end
			end)
		end

		-- reapply speed / jump
		pcall(function()
			if lp.Character and lp.Character:FindFirstChild("Humanoid") then
				local hum = lp.Character.Humanoid
				if cfg.speed ~= 16 then hum.WalkSpeed = cfg.speed end
				if cfg.jumpPow ~= 50 then hum.JumpPower = cfg.jumpPow end
			end
		end)

		task.wait(0.2)
	end
end

-- cleanup
module.Cleanup = function()
	clearAllESP()
	clearGunESP()
	cachedRoles = {}

	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	conns = {}

	pcall(function()
		if lp.Character and lp.Character:FindFirstChild("Humanoid") then
			lp.Character.Humanoid.WalkSpeed = 16
			lp.Character.Humanoid.JumpPower = 50
		end
	end)
end

return module
