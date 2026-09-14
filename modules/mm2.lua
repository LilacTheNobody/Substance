-- mm2 module
-- substance

local module = {}

local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local vu = game:GetService("VirtualUser")
local lp = plrs.LocalPlayer

-- notification helper
local cachedApi = nil
local function apiNotify(cfg)
	if cachedApi and cachedApi.Notify then
		pcall(cachedApi.Notify, cfg)
	end
end

-- settings
local cfg = {
	esp = false,
	roles = {
		Murderer = true,
		Sheriff = true,
		Innocent = false,
	},
	gunEsp = true,
	trapEsp = false,
	showNames = true,
	showDist = true,
	murdererWarn = false,
	roleAnnounce = true,

	-- combat
	autoShoot = false,
	shootOffset = 3.5,
	knifeAura = false,
	auraRange = 15,
	autoKill = false,

	-- utility
	autoGun = false,
	autoCoins = false,
	antiAfk = true,

	-- movement
	speedEnabled = false,
	speed = 16,
	jumpEnabled = false,
	jumpPow = 50,
}

local colors = {
	Murderer = Color3.fromRGB(255, 35, 35),
	Sheriff = Color3.fromRGB(35, 135, 255),
	Innocent = Color3.fromRGB(40, 225, 85),
	Gun = Color3.fromRGB(255, 215, 0),
	Trap = Color3.fromRGB(255, 140, 0),
}

local cachedRoles = {}
local highlights = {}
local billboards = {}
local trapHighlights = {}
local gunHL = nil
local gunBB = nil
local conns = {}

-- weapon check helper (strictly checks Tool instances only)
local function checkItem(item, kind)
	if not item or not item:IsA("Tool") then return false end
	local n = item.Name:lower()

	local isGun = (n == "gun" or n == "revolver" or n:find("gun") ~= nil or n:find("revolver") ~= nil
		or item:FindFirstChild("GunScript") ~= nil
		or item:FindFirstChild("ShootGun") ~= nil
		or item:FindFirstChild("GunLevel") ~= nil)

	local isKnife = (n == "knife" or n:find("knife") ~= nil
		or item:FindFirstChild("ThrowKnife") ~= nil
		or item:FindFirstChild("KnifeScript") ~= nil
		or (item:FindFirstChild("KnifeServer") ~= nil and not isGun))

	if kind == "gun" then
		return isGun
	elseif kind == "knife" then
		return isKnife and not isGun
	end
	return false
end

local function scanPlayer(p)
	if not p or not p.Parent then return nil end

	-- check character first (strictly Tool instances)
	local ch = p.Character
	if ch then
		for _, item in ipairs(ch:GetChildren()) do
			if item:IsA("Tool") then
				if checkItem(item, "gun") then return "Sheriff" end
				if checkItem(item, "knife") then return "Murderer" end
			end
		end
	end

	-- check backpack (strictly Tool instances)
	local bp = p:FindFirstChild("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") then
				if checkItem(item, "gun") then return "Sheriff" end
				if checkItem(item, "knife") then return "Murderer" end
			end
		end
	end

	return nil
end

local function getRole(p)
	if p == lp then
		local r = scanPlayer(lp)
		return r or "Innocent"
	end

	-- check live inventory
	local found = scanPlayer(p)
	if found then
		cachedRoles[p] = found
		return found
	end

	-- if sheriff died and gun is on the ground, reset sheriff cache for dead player
	if cachedRoles[p] == "Sheriff" then
		local ch = p.Character
		local hum = ch and ch:FindFirstChild("Humanoid")
		if (not ch or not hum or hum.Health <= 0) and workspace:FindFirstChild("GunDrop") then
			cachedRoles[p] = nil
			return "Innocent"
		end
	end

	-- keep cached role for the round
	if cachedRoles[p] then
		return cachedRoles[p]
	end

	return "Innocent"
end

local function getMurderer()
	for _, p in ipairs(plrs:GetPlayers()) do
		if getRole(p) == "Murderer" then
			local ch = p.Character
			local hum = ch and ch:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 then
				return p
			end
		end
	end
	return nil
end

local function getSheriff()
	for _, p in ipairs(plrs:GetPlayers()) do
		if getRole(p) == "Sheriff" then
			local ch = p.Character
			local hum = ch and ch:FindFirstChild("Humanoid")
			if hum and hum.Health > 0 then
				return p
			end
		end
	end
	return nil
end

-- esp cleanup
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
	for p in pairs(highlights) do clearPlayerESP(p) end
	for p in pairs(billboards) do clearPlayerESP(p) end
end

local function clearGunESP()
	if gunHL then pcall(function() gunHL:Destroy() end); gunHL = nil end
	if gunBB then pcall(function() gunBB:Destroy() end); gunBB = nil end
end

local function clearTrapESP()
	for _, hl in pairs(trapHighlights) do
		pcall(function() hl:Destroy() end)
	end
	trapHighlights = {}
end

-- high quality esp renderer
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
		hl.Name = "SubstanceESP"
		hl.Adornee = ch
		hl.FillColor = col
		hl.FillTransparency = 0.55
		hl.OutlineColor = col
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = ch
		highlights[p] = hl
	else
		hl.FillColor = col
		hl.OutlineColor = col
	end

	-- billboard gui
	local bb = billboards[p]
	if not bb or bb.Parent ~= head then
		if bb then pcall(function() bb:Destroy() end) end
		bb = Instance.new("BillboardGui")
		bb.Name = "SubstanceLabel"
		bb.Adornee = head
		bb.Size = UDim2.fromOffset(180, 40)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 600

		local rTag = Instance.new("TextLabel")
		rTag.Name = "RoleTag"
		rTag.Size = UDim2.new(1, 0, 0.52, 0)
		rTag.BackgroundTransparency = 1
		rTag.Font = Enum.Font.GothamBold
		rTag.TextSize = 13
		rTag.TextColor3 = col
		rTag.TextStrokeTransparency = 0.15
		rTag.TextStrokeColor3 = Color3.new(0, 0, 0)
		rTag.Parent = bb

		local iTag = Instance.new("TextLabel")
		iTag.Name = "InfoTag"
		iTag.Size = UDim2.new(1, 0, 0.48, 0)
		iTag.Position = UDim2.new(0, 0, 0.52, 0)
		iTag.BackgroundTransparency = 1
		iTag.Font = Enum.Font.Gotham
		iTag.TextSize = 11
		iTag.TextColor3 = Color3.fromRGB(225, 225, 225)
		iTag.TextStrokeTransparency = 0.2
		iTag.TextStrokeColor3 = Color3.new(0, 0, 0)
		iTag.Parent = bb

		bb.Parent = head
		billboards[p] = bb
	end

	local rt = bb:FindFirstChild("RoleTag")
	local it = bb:FindFirstChild("InfoTag")
	if rt then
		rt.Text = "[" .. role:upper() .. "]"
		rt.TextColor3 = col
	end
	if it then
		local details = {}
		if cfg.showNames then
			table.insert(details, p.DisplayName)
		end
		if cfg.showDist and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
			local dist = math.floor((lp.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
			table.insert(details, tostring(dist) .. "m")
		end
		it.Text = table.concat(details, " | ")
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
		hl.FillTransparency = 0.35
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
		bb.Size = UDim2.fromOffset(150, 26)
		bb.StudsOffset = Vector3.new(0, 2.2, 0)
		bb.AlwaysOnTop = true

		local tag = Instance.new("TextLabel")
		tag.Name = "GunText"
		tag.Size = UDim2.new(1, 0, 1, 0)
		tag.BackgroundTransparency = 1
		tag.Font = Enum.Font.GothamBold
		tag.TextSize = 13
		tag.TextColor3 = colors.Gun
		tag.TextStrokeTransparency = 0.2
		tag.TextStrokeColor3 = Color3.new(0, 0, 0)
		tag.Text = "[DROPPED GUN]"
		tag.Parent = bb

		bb.Parent = gd
		gunBB = bb
	end

	if gunBB and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
		local gt = gunBB:FindFirstChild("GunText")
		if gt then
			local dist = math.floor((lp.Character.HumanoidRootPart.Position - gd:GetPivot().Position).Magnitude)
			gt.Text = "[DROPPED GUN] " .. tostring(dist) .. "m"
		end
	end
end

-- trap esp
local function updateTrapESP()
	if not cfg.trapEsp then
		clearTrapESP()
		return
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj:IsA("BasePart") or obj:IsA("Model")) and obj.Name:lower():find("trap") ~= nil then
			if not obj:IsDescendantOf(lp.Character or workspace) == false and not trapHighlights[obj] then
				local hl = Instance.new("Highlight")
				hl.Name = "SubTrapESP"
				hl.Adornee = obj
				hl.FillColor = colors.Trap
				hl.FillTransparency = 0.45
				hl.OutlineColor = colors.Trap
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = obj
				trapHighlights[obj] = hl
			end
		end
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
				task.wait(0.08)
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

-- check if a player is in the lobby (waiting / eliminated / not on active map)
local function isPlayerInLobby(p)
	local ch = p.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return true end

	-- 1. Check if workspace.Lobby exists and player is inside or near it
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby then
		local spawns = lobby:FindFirstChild("Spawns")
		if spawns then
			local spawnPos = spawns:GetPivot().Position
			if (hrp.Position - spawnPos).Magnitude < 175 then
				return true
			end
		end
		local ok, lobbyCf, lobbySize = pcall(function() return lobby:GetBoundingBox() end)
		if ok and lobbyCf and lobbySize then
			local relPos = lobbyCf:PointToObjectSpace(hrp.Position)
			local halfSize = lobbySize / 2 + Vector3.new(30, 30, 30)
			if math.abs(relPos.X) <= halfSize.X and math.abs(relPos.Y) <= halfSize.Y and math.abs(relPos.Z) <= halfSize.Z then
				return true
			end
		end
	end

	-- 2. Check distance relative to local player (Murderer/Sheriff is inside the map)
	local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if myHrp then
		local dist = (hrp.Position - myHrp.Position).Magnitude
		-- Active MM2 maps are ~150-250 studs across; lobby is 500-2500+ studs away
		if dist > 550 then
			return true
		end
	end

	-- 3. Check active map container (workspace.Normal) if present
	local activeMap = workspace:FindFirstChild("Normal")
	if activeMap then
		local ok, mapCf, mapSize = pcall(function() return activeMap:GetBoundingBox() end)
		if ok and mapCf and mapSize then
			local relPos = mapCf:PointToObjectSpace(hrp.Position)
			local halfSize = mapSize / 2 + Vector3.new(45, 45, 45)
			if math.abs(relPos.X) > halfSize.X or math.abs(relPos.Y) > halfSize.Y or math.abs(relPos.Z) > halfSize.Z then
				return true
			end
		end
	end

	return false
end

-- shoots murderer by bringing them directly in front of you and firing revolver
local function shootMurderer()
	local m = getMurderer()
	if not m or not m.Character then return false end
	local ch = lp.Character
	if not ch then return false end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then return false end

	-- Exclude murderer if in lobby or dead
	if isPlayerInLobby(m) then return false end
	local mHrp = m.Character:FindFirstChild("HumanoidRootPart")
	local mHum = m.Character:FindFirstChildOfClass("Humanoid")
	if not mHrp or not mHum or mHum.Health <= 0 then return false end

	-- Equip Gun if in backpack
	local gun = ch:FindFirstChild("Gun") or ch:FindFirstChild("Revolver")
	if not gun then
		local bp = lp:FindFirstChild("Backpack")
		if bp then
			local bg = bp:FindFirstChild("Gun") or bp:FindFirstChild("Revolver")
			if bg then
				hum:EquipTool(bg)
				task.wait(0.08)
				gun = ch:FindFirstChild("Gun") or ch:FindFirstChild("Revolver")
			end
		end
	end
	if not gun then return false end

	-- Bring Murderer directly in front of the local player (aim line)
	local targetSpot = hrp.CFrame * CFrame.new(0, 0, -3.2)
	pcall(function()
		mHrp.CFrame = targetSpot
		mHrp.AssemblyLinearVelocity = Vector3.zero
		mHrp.AssemblyAngularVelocity = Vector3.zero
		if m.Character:FindFirstChild("UpperTorso") then
			m.Character.UpperTorso.CFrame = targetSpot
		elseif m.Character:FindFirstChild("Torso") then
			m.Character.Torso.CFrame = targetSpot
		end
		if m.Character:FindFirstChild("Head") then
			m.Character.Head.CFrame = targetSpot + Vector3.new(0, 1.4, 0)
		end
	end)

	task.wait(0.05)

	local aimPos = mHrp.Position
	if m.Character:FindFirstChild("Head") then
		aimPos = m.Character.Head.Position
	end

	return shootAt(aimPos)
end

local function isAliveTarget(p)
	if not p or not p.Parent or p == lp then return false end
	local ch = p.Character
	if not ch or not ch.Parent then return false end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local head = ch:FindFirstChild("Head")
	if not hum or not hrp or not head then return false end
	if hum.Health <= 0 then return false end
	if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
	if ch:FindFirstChild("Dead") then return false end
	if ch:FindFirstChildOfClass("ForceField") then return false end
	if ch:FindFirstChild("Ragdoll") or ch:FindFirstChild("Ragdolled") then return false end

	-- Exclude players in the lobby (not on the map)
	if isPlayerInLobby(p) then
		return false
	end

	return true
end

local function killAll()
	if isKillingAll then return end
	local ch = lp.Character
	if not ch then return end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return end

	local knife = ch:FindFirstChild("Knife") or (lp.Backpack and lp.Backpack:FindFirstChild("Knife"))
	if not knife then return end

	-- filter all valid alive players first
	local targets = {}
	for _, p in ipairs(plrs:GetPlayers()) do
		if isAliveTarget(p) then
			table.insert(targets, p)
		end
	end

	if #targets == 0 then return end

	isKillingAll = true

	if knife.Parent == lp.Backpack then
		hum:EquipTool(knife)
		task.wait(0.1)
	end

	local knifeHandle = knife:FindFirstChild("Handle")

	for _, p in ipairs(targets) do
		if isAliveTarget(p) then
			local tch = p.Character
			local thrp = tch and tch:FindFirstChild("HumanoidRootPart")
			if thrp and hrp and hrp.Parent then
				-- Bring target directly in front of the local player (local player never teleports away)
				local strikeCf = hrp.CFrame * CFrame.new(0, 0, -2.4)
				pcall(function()
					thrp.CFrame = strikeCf
					thrp.AssemblyLinearVelocity = Vector3.zero
					thrp.AssemblyAngularVelocity = Vector3.zero
					if tch:FindFirstChild("UpperTorso") then
						tch.UpperTorso.CFrame = strikeCf
					elseif tch:FindFirstChild("Torso") then
						tch.Torso.CFrame = strikeCf
					end
				end)

				-- Slash knife
				pcall(function()
					knife:Activate()
					if knifeHandle and typeof(firetouchinterest) == "function" then
						firetouchinterest(thrp, knifeHandle, 0)
						firetouchinterest(thrp, knifeHandle, 1)
					end
				end)

				task.wait(0.08)
			end
		end
	end

	isKillingAll = false
end

-- bring gun helper with fast container lookup
local function findGunDrop()
	local gd = workspace:FindFirstChild("GunDrop")
	if gd then return gd end
	local normal = workspace:FindFirstChild("Normal")
	if normal then
		gd = normal:FindFirstChild("GunDrop")
		if gd then return gd end
	end
	for _, v in ipairs(workspace:GetDescendants()) do
		if v.Name == "GunDrop" and (v:IsA("BasePart") or v:IsA("Model")) then
			return v
		end
	end
	return nil
end

local function bringGun()
	local gd = findGunDrop()
	if not gd then
		return false, "Gun is not dropped on the map"
	end

	local ch = lp.Character
	if not ch or not ch:FindFirstChild("HumanoidRootPart") then return false, "Character not ready" end
	local hrp = ch.HumanoidRootPart
	local origCf = hrp.CFrame

	-- Method 1: Bring GunDrop part directly to player RootPart
	pcall(function()
		if gd:IsA("BasePart") then
			gd.CFrame = hrp.CFrame
		elseif gd:IsA("Model") then
			gd:PivotTo(hrp.CFrame)
		end
	end)

	task.wait(0.12)
	local hasGun = lp.Backpack:FindFirstChild("Gun") or lp.Backpack:FindFirstChild("Revolver") or (ch and (ch:FindFirstChild("Gun") or ch:FindFirstChild("Revolver")))
	if not hasGun then
		-- Method 2: Fast touch teleport with safe return
		local gunPos = gd:GetPivot().Position
		hrp.CFrame = CFrame.new(gunPos + Vector3.new(0, 1.5, 0))
		task.wait(0.2)
		for _ = 1, 5 do
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			hrp.CFrame = origCf
			task.wait(0.02)
		end
	end
	return true, "Gun collected!"
end

-- optimized coin grabber (checks CoinContainer first before heavy scans)
local function grabCoins()
	local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end
	local count = 0

	local container = nil
	local normal = workspace:FindFirstChild("Normal")
	if normal then
		container = normal:FindFirstChild("CoinContainer")
	end
	if not container then
		container = workspace:FindFirstChild("CoinContainer")
	end

	if container then
		for _, obj in ipairs(container:GetChildren()) do
			if obj:IsA("BasePart") then
				pcall(function()
					obj.CFrame = hrp.CFrame
					count = count + 1
				end)
			end
		end
		return count
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and (obj.Name == "Coin" or obj.Name == "Coin_Server" or obj.Name:find("Coin") ~= nil) then
			pcall(function()
				obj.CFrame = hrp.CFrame
				count = count + 1
			end)
		end
	end
	return count
end

-- disarm traps
local function disarmTraps()
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj:IsA("BasePart") or obj:IsA("Model")) and obj.Name:lower():find("trap") ~= nil then
			pcall(function()
				if obj:IsA("BasePart") then
					obj.CFrame = CFrame.new(0, -500, 0)
					obj.CanCollide = false
				elseif obj:IsA("Model") then
					obj:PivotTo(CFrame.new(0, -500, 0))
				end
				count = count + 1
			end)
		end
	end
	return count
end

-- humanoid duplication godmode
local function enableGodmode()
	local ch = lp.Character
	if not ch then return false, "Character not found" end
	local hum = ch:FindFirstChild("Humanoid")
	if not hum then return false, "Humanoid not found" end

	pcall(function()
		hum.Name = "1"
		local clone = ch["1"]:Clone()
		clone.Parent = ch
		clone.Name = "Humanoid"
		task.wait(0.1)
		ch["1"]:Destroy()
		workspace.CurrentCamera.CameraSubject = clone
		if ch:FindFirstChild("Animate") then
			ch.Animate.Disabled = true
			task.wait(0.1)
			ch.Animate.Disabled = false
		end
	end)
	return true, "God Mode active! (Do not reset character)"
end

-- aggressive multi-angle skid fling on murderer
local function flingMurderer()
	local m = getMurderer()
	if not m or not m.Character then return false, "Murderer not found or dead" end
	local ch = lp.Character
	local tch = m.Character
	if not ch or not tch then return false, "Character not ready" end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local thrp = tch:FindFirstChild("HumanoidRootPart")
	local thum = tch:FindFirstChild("Humanoid")
	if not hrp or not thrp or not thum or thum.Health <= 0 then return false, "Murderer not alive" end

	local savedPos = hrp.CFrame

	hrp.CanCollide = true

	local bav = Instance.new("BodyAngularVelocity")
	bav.AngularVelocity = Vector3.new(0, 9999999, 0)
	bav.MaxTorque = Vector3.new(0, math.huge, 0)
	bav.P = math.huge
	bav.Parent = hrp

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Velocity = Vector3.new(0, 1000, 0)
	bv.Parent = hrp

	local t0 = tick()
	while tick() - t0 < 1.3 and thrp.Parent and thum.Health > 0 do
		local pred = thrp.AssemblyLinearVelocity * 0.04
		local offset = Vector3.new(math.random(-1, 1) * 0.4, -0.6, math.random(-1, 1) * 0.4)
		hrp.CFrame = CFrame.new(thrp.Position + offset + pred) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 9999999, 0)
		rs.Heartbeat:Wait()

		if thrp.AssemblyLinearVelocity.Magnitude > 120 or thum.Health <= 0 then
			break
		end
	end

	pcall(function() bav:Destroy() end)
	pcall(function() bv:Destroy() end)

	for _ = 1, 10 do
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = savedPos
		rs.RenderStepped:Wait()
	end
	return true, "Murderer flung!"
end

-- persistent speed & jump sync with hub or standalone fallback
local isApplyingLocal = false
local function applyLocalSpeed()
	if _G.SubstanceCharMods then
		_G.SubstanceCharMods.speedEnabled = cfg.speedEnabled
		_G.SubstanceCharMods.speed = cfg.speed
		_G.SubstanceCharMods.jumpEnabled = cfg.jumpEnabled
		_G.SubstanceCharMods.jump = cfg.jumpPow
		if _G.SubstanceApplySpeed then
			_G.SubstanceApplySpeed()
		end
		return
	end

	if isApplyingLocal then return end
	if not (cfg.speedEnabled or cfg.jumpEnabled) then return end
	isApplyingLocal = true
	pcall(function()
		local ch = lp.Character
		if ch then
			local hum = ch:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				if cfg.speedEnabled and math.abs(hum.WalkSpeed - cfg.speed) > 0.05 then
					hum.WalkSpeed = cfg.speed
				end
				if cfg.jumpEnabled then
					if not hum.UseJumpPower then
						hum.UseJumpPower = true
					end
					if math.abs(hum.JumpPower - cfg.jumpPow) > 0.05 then
						hum.JumpPower = cfg.jumpPow
					end
					local targetHeight = (cfg.jumpPow / 50) * 7.2
					if math.abs(hum.JumpHeight - targetHeight) > 0.1 then
						hum.JumpHeight = targetHeight
					end
				end
			end
		end
	end)
	isApplyingLocal = false
end

local function restoreLocalDefaultMovement()
	if _G.SubstanceRestoreMovement then
		if _G.SubstanceCharMods then
			_G.SubstanceCharMods.speedEnabled = cfg.speedEnabled
			_G.SubstanceCharMods.jumpEnabled = cfg.jumpEnabled
		end
		_G.SubstanceRestoreMovement()
		return
	end
	pcall(function()
		local ch = lp.Character
		if ch then
			local hum = ch:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				if not cfg.speedEnabled and math.abs(hum.WalkSpeed - 16) > 0.05 then
					hum.WalkSpeed = 16
				end
				if not cfg.jumpEnabled then
					hum.JumpPower = 50
					hum.JumpHeight = 7.2
				end
			end
		end
	end)
end

local function hookLocalHumanoid(ch)
	task.defer(function()
		if cfg.speedEnabled or cfg.jumpEnabled then
			applyLocalSpeed()
		end
	end)
end

-- fullbright helper
local function setFullbright(v)
	cfg.fullbright = v
	local lighting = game:GetService("Lighting")
	pcall(function()
		if v then
			lighting.Ambient = Color3.fromRGB(255, 255, 255)
			lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
			lighting.Brightness = 2
			lighting.ClockTime = 14
			lighting.FogEnd = 1e5
		else
			lighting.Ambient = Color3.fromRGB(128, 128, 128)
			lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
			lighting.Brightness = 1
			lighting.ClockTime = 14
			lighting.FogEnd = 10000
		end
	end)
end

-- spectate helper
local function spectateTarget(p)
	if p and p.Character and p.Character:FindFirstChild("Humanoid") then
		workspace.CurrentCamera.CameraSubject = p.Character.Humanoid
		return true
	end
	if lp.Character and lp.Character:FindFirstChild("Humanoid") then
		workspace.CurrentCamera.CameraSubject = lp.Character.Humanoid
	end
	return false
end

-- warning & announcer helpers
local lastWarnTime = 0
local lastAnnouncedRound = nil

local function checkMurdererWarning()
	if not cfg.murdererWarn then return end
	if getRole(lp) == "Murderer" then return end

	local m = getMurderer()
	if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
		local dist = math.floor((lp.Character.HumanoidRootPart.Position - m.Character.HumanoidRootPart.Position).Magnitude)
		if dist <= 35 and (tick() - lastWarnTime > 6) then
			lastWarnTime = tick()
			apiNotify({
				Title = "Murderer Nearby",
				Content = "Watch out! " .. m.DisplayName .. " is " .. tostring(dist) .. "m away!",
				Duration = 3,
			})
		end
	end
end

local function checkRoleAnnounce()
	if not cfg.roleAnnounce then return end
	local m = getMurderer()
	local s = getSheriff()
	if m and m ~= lastAnnouncedRound then
		lastAnnouncedRound = m
		local sName = s and s.DisplayName or "None / Dropped"
		apiNotify({
			Title = "Round Roles",
			Content = "Murderer: " .. m.DisplayName .. "\nSheriff: " .. sName,
			Duration = 4.5,
		})
	end
end

-- module metadata
module.Name = "MM2"
module.GameId = 142823291
module.GameName = "Murder Mystery 2"
module.Author = "Substance"
module.Version = "2.4"
module.Icon = "crosshair"

-- ui elements
module.Elements = {
	{ Type = "Section", Name = "ESP" },

	{
		Type = "Toggle",
		Name = "Enable ESP",
		Description = "Master toggle for all ESP overlays",
		Default = false,
		Callback = function(v)
			cfg.esp = v
			if not v then
				clearAllESP()
			end
		end,
	},

	{
		Type = "Toggle",
		Name = "Murderer ESP",
		Description = "Highlights the Murderer in crimson red",
		Default = true,
		Callback = function(v)
			cfg.roles.Murderer = v
			for p in pairs(highlights) do
				if getRole(p) == "Murderer" and not v then
					clearPlayerESP(p)
				end
			end
		end,
	},

	{
		Type = "Toggle",
		Name = "Sheriff ESP",
		Description = "Highlights the Sheriff or Hero in vibrant blue",
		Default = true,
		Callback = function(v)
			cfg.roles.Sheriff = v
			for p in pairs(highlights) do
				if getRole(p) == "Sheriff" and not v then
					clearPlayerESP(p)
				end
			end
		end,
	},

	{
		Type = "Toggle",
		Name = "Innocent ESP",
		Description = "Highlights all Innocent players in green",
		Default = false,
		Callback = function(v)
			cfg.roles.Innocent = v
			for p in pairs(highlights) do
				if getRole(p) == "Innocent" and not v then
					clearPlayerESP(p)
				end
			end
		end,
	},

	{
		Type = "Toggle",
		Name = "Dropped Gun ESP",
		Description = "Highlights dropped sheriff gun in gold with distance",
		Default = true,
		Callback = function(v)
			cfg.gunEsp = v
			if not v then clearGunESP() end
		end,
	},

	{
		Type = "Toggle",
		Name = "Trap ESP",
		Description = "Highlights murderer traps in bright orange",
		Default = false,
		Callback = function(v)
			cfg.trapEsp = v
			if not v then clearTrapESP() end
		end,
	},

	{
		Type = "Toggle",
		Name = "Show Names",
		Description = "Displays player display names above heads",
		Default = true,
		Callback = function(v)
			cfg.showNames = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Show Distance",
		Description = "Displays distance in meters on player tags",
		Default = true,
		Callback = function(v)
			cfg.showDist = v
		end,
	},

	{ Type = "Section", Name = "Combat" },

	{
		Type = "Button",
		Name = "Shoot Murderer",
		Description = "Fires revolver at Murderer with velocity prediction",
		Callback = function()
			shootMurderer()
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Shoot Murderer",
		Description = "Automatically fires at Murderer when holding Gun",
		Default = false,
		Callback = function(v)
			cfg.autoShoot = v
		end,
	},

	{
		Type = "Button",
		Name = "Kill All",
		Description = "Stabs every alive player (Murderer only)",
		Callback = function()
			killAll()
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Kill All",
		Description = "Continues stabbing players while you are Murderer",
		Default = false,
		Callback = function(v)
			cfg.autoKill = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Knife Aura",
		Description = "Automatically slashes players nearby when holding knife",
		Default = false,
		Callback = function(v)
			cfg.knifeAura = v
		end,
	},

	{
		Type = "Slider",
		Name = "Aura Distance",
		Min = 5,
		Max = 35,
		Default = 15,
		Rounding = 1,
		Callback = function(v)
			cfg.auraRange = v
		end,
	},

	{
		Type = "Button",
		Name = "Fling Murderer",
		Description = "Launches the Murderer into orbit and teleports you back safely",
		Callback = function()
			local ok, msg = flingMurderer()
			if ok then
				apiNotify({ Title = "Fling Murderer", Content = msg or "Murderer flung!", Duration = 3 })
			else
				apiNotify({ Title = "Fling Murderer", Content = msg or "Failed to fling", Duration = 2 })
			end
		end,
	},

	{ Type = "Section", Name = "Automation & Utility" },

	{
		Type = "Button",
		Name = "Teleport Gun",
		Description = "Brings dropped gun to your position or grabs it instantly",
		Callback = function()
			local ok, msg = bringGun()
			apiNotify({ Title = "Teleport Gun", Content = msg or "Done", Duration = 3 })
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Grab Dropped Gun",
		Description = "Instantly collects gun the moment Sheriff drops it",
		Default = false,
		Callback = function(v)
			cfg.autoGun = v
		end,
	},

	{
		Type = "Button",
		Name = "Coin Grabber",
		Description = "Teleports all spawned coins in the workspace directly to you",
		Callback = function()
			local count = grabCoins()
			apiNotify({ Title = "Coin Grabber", Content = "Brought " .. tostring(count) .. " coins to you!", Duration = 3 })
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Coin Farm",
		Description = "Collects coins around the map continuously",
		Default = false,
		Callback = function(v)
			cfg.autoCoins = v
		end,
	},

	{
		Type = "Button",
		Name = "Disarm Traps",
		Description = "Removes all murderer traps on the map",
		Callback = function()
			local count = disarmTraps()
			apiNotify({ Title = "Traps Disarmed", Content = "Removed " .. tostring(count) .. " traps!", Duration = 3 })
		end,
	},

	{
		Type = "Toggle",
		Name = "Murderer Warning",
		Description = "Warns you when the Murderer is within 35 studs",
		Default = false,
		Callback = function(v)
			cfg.murdererWarn = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Role Announcer",
		Description = "Notifies who the Murderer and Sheriff are at round start",
		Default = true,
		Callback = function(v)
			cfg.roleAnnounce = v
		end,
	},

	{
		Type = "Button",
		Name = "God Mode",
		Description = "Clones humanoid to prevent damage (Do not reset while active)",
		Callback = function()
			local ok, msg = enableGodmode()
			apiNotify({ Title = "God Mode", Content = msg, Duration = 4 })
		end,
	},

	{
		Type = "Toggle",
		Name = "Anti AFK",
		Description = "Prevents 20-minute idle disconnect",
		Default = true,
		Callback = function(v)
			cfg.antiAfk = v
		end,
	},

	{ Type = "Section", Name = "Visuals & Camera" },

	{
		Type = "Toggle",
		Name = "Fullbright",
		Description = "Illuminates dark maps completely for crystal-clear vision",
		Default = false,
		Callback = function(v)
			setFullbright(v)
		end,
	},

	{
		Type = "Button",
		Name = "Spectate Murderer",
		Description = "Follows the Murderer with camera",
		Callback = function()
			local m = getMurderer()
			if m then
				spectateTarget(m)
				apiNotify({ Title = "Spectate", Content = "Spectating " .. m.DisplayName, Duration = 2 })
			else
				apiNotify({ Title = "Spectate", Content = "Murderer not found or not in map", Duration = 2 })
			end
		end,
	},

	{
		Type = "Button",
		Name = "Spectate Sheriff",
		Description = "Follows the Sheriff with camera",
		Callback = function()
			local s = getSheriff()
			if s then
				spectateTarget(s)
				apiNotify({ Title = "Spectate", Content = "Spectating " .. s.DisplayName, Duration = 2 })
			else
				apiNotify({ Title = "Spectate", Content = "Sheriff not found or gun dropped", Duration = 2 })
			end
		end,
	},

	{
		Type = "Button",
		Name = "Reset Camera (Unspectate)",
		Description = "Returns camera back to your own character",
		Callback = function()
			spectateTarget(lp)
		end,
	},

	{ Type = "Section", Name = "Movement" },

	{
		Type = "Toggle",
		Name = "Enable WalkSpeed",
		Description = "Locks custom speed even when equipping or slashing knife",
		Default = false,
		Callback = function(v)
			cfg.speedEnabled = v
			if v then
				applyLocalSpeed()
			else
				restoreLocalDefaultMovement()
			end
		end,
	},

	{
		Type = "Slider",
		Name = "WalkSpeed",
		Min = 16,
		Max = 200,
		Default = 16,
		Rounding = 1,
		Callback = function(v)
			cfg.speed = v
			if cfg.speedEnabled then
				applyLocalSpeed()
			end
		end,
	},

	{
		Type = "Toggle",
		Name = "Enable JumpPower",
		Description = "Locks custom jump power",
		Default = false,
		Callback = function(v)
			cfg.jumpEnabled = v
			if v then
				applyLocalSpeed()
			else
				restoreLocalDefaultMovement()
			end
		end,
	},

	{
		Type = "Slider",
		Name = "JumpPower",
		Min = 50,
		Max = 300,
		Default = 50,
		Rounding = 1,
		Callback = function(v)
			cfg.jumpPow = v
			if cfg.jumpEnabled then
				applyLocalSpeed()
			end
		end,
	},

	{
		Type = "Button",
		Name = "Reset Movement",
		Description = "Restores default WalkSpeed (16) and JumpPower (50)",
		Callback = function()
			cfg.speedEnabled = false
			cfg.jumpEnabled = false
			cfg.speed = 16
			cfg.jumpPow = 50
			restoreLocalDefaultMovement()
			apiNotify({ Title = "Movement", Content = "Restored default speed and jump", Duration = 2 })
		end,
	},
}

-- init hooks & round persistence
module.Init = function(api)
	cachedApi = api
	if lp.Character then hookLocalHumanoid(lp.Character) end
	table.insert(conns, lp.CharacterAdded:Connect(function(newChar)
		hookLocalHumanoid(newChar)
	end))

	-- only bind local heartbeat if hub is not already managing global movement
	if not _G.SubstanceCharMods then
		table.insert(conns, rs.Heartbeat:Connect(function()
			if cfg.speedEnabled or cfg.jumpEnabled then
				applyLocalSpeed()
			end
		end))
	end

	-- round reset & player respawn hooks
	local function hookPlayer(p)
		table.insert(conns, p.CharacterAdded:Connect(function(newChar)
			cachedRoles[p] = nil
			clearPlayerESP(p)
			task.wait(0.6)
			if cfg.esp then
				pcall(function() updatePlayerESP(p) end)
			end
		end))
	end

	for _, p in ipairs(plrs:GetPlayers()) do
		if p ~= lp then hookPlayer(p) end
	end
	table.insert(conns, plrs.PlayerAdded:Connect(hookPlayer))

	table.insert(conns, plrs.PlayerRemoving:Connect(function(p)
		cachedRoles[p] = nil
		clearPlayerESP(p)
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

	-- dropped gun monitor
	table.insert(conns, workspace.ChildAdded:Connect(function(child)
		if child.Name == "GunDrop" then
			task.wait(0.1)
			if cfg.gunEsp then pcall(updateGunESP) end
			if cfg.autoGun then
				task.spawn(function()
					bringGun()
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

-- bulletproof background loop (never dies across rounds)
local lastAutoKill = 0
local lastAutoShoot = 0

module.BackgroundTask = function(api)
	cachedApi = api
	while api.Running do
		pcall(function()
			-- esp update
			if cfg.esp then
				for _, p in ipairs(plrs:GetPlayers()) do
					if p ~= lp then
						pcall(function() updatePlayerESP(p) end)
					end
				end
			end

			-- gun esp update
			if cfg.gunEsp then
				pcall(updateGunESP)
			end

			-- trap esp update
			if cfg.trapEsp then
				pcall(updateTrapESP)
			end

			-- proximity & announcer
			checkMurdererWarning()
			checkRoleAnnounce()

			-- auto shoot murderer (teleports murderer directly to you and shoots)
			if cfg.autoShoot and (tick() - lastAutoShoot > 1.1) then
				pcall(function()
					local hasGun = (lp.Character and (lp.Character:FindFirstChild("Gun") or lp.Character:FindFirstChild("Revolver")))
						or (lp.Backpack and (lp.Backpack:FindFirstChild("Gun") or lp.Backpack:FindFirstChild("Revolver")))
					if hasGun then
						local m = getMurderer()
						if m and m.Character and not isPlayerInLobby(m) then
							local mHum = m.Character:FindFirstChildOfClass("Humanoid")
							if mHum and mHum.Health > 0 then
								lastAutoShoot = tick()
								task.spawn(shootMurderer)
							end
						end
					end
				end)
			end

			-- auto kill all (murderer only, throttled to prevent spamming)
			if cfg.autoKill and getRole(lp) == "Murderer" and (tick() - lastAutoKill > 1.0) then
				lastAutoKill = tick()
				task.spawn(killAll)
			end

			-- knife aura
			if cfg.knifeAura and getRole(lp) == "Murderer" then
				pcall(function()
					local ch = lp.Character
					if ch and ch:FindFirstChild("HumanoidRootPart") then
						local knife = ch:FindFirstChild("Knife") or (lp.Backpack and lp.Backpack:FindFirstChild("Knife"))
						if knife then
							for _, p in ipairs(plrs:GetPlayers()) do
								if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
									local tHum = p.Character:FindFirstChild("Humanoid")
									if tHum and tHum.Health > 0 and not isPlayerInLobby(p) then
										local dist = (ch.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position).Magnitude
										if dist <= cfg.auraRange then
											if knife.Parent == lp.Backpack then
												ch.Humanoid:EquipTool(knife)
											end
											knife:Activate()
										end
									end
								end
							end
						end
					end
				end)
			end

			-- auto coin farm
			if cfg.autoCoins and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
				pcall(function()
					local count = grabCoins()
					if count == 0 then
						for _, obj in ipairs(workspace:GetDescendants()) do
							if obj.Name == "Coin_Server" or obj.Name == "Coin" then
								if obj:IsA("BasePart") or obj:IsA("Model") then
									local coinPos = obj:GetPivot().Position
									lp.Character.HumanoidRootPart.CFrame = CFrame.new(coinPos + Vector3.new(0, 1.5, 0))
									task.wait(0.25)
									break
								end
							end
						end
					end
				end)
			end
		end)

		task.wait(0.18)
	end
end

-- cleanup
module.Cleanup = function()
	clearAllESP()
	clearGunESP()
	clearTrapESP()
	cachedRoles = {}
	setFullbright(false)
	spectateTarget(lp)

	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	conns = {}

	restoreLocalDefaultMovement()
end

return module
