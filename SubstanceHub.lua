-- substance hub
-- universal script hub with glass acrylic ui

if not game:IsLoaded() then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Substance",
			Text = "Waiting for game to load...",
			Duration = 4,
		})
	end)
	game.Loaded:Wait()
end

-- loader helper
local function fetchScript(url, fallbackFile)
	local content = ""
	pcall(function()
		content = game:HttpGet(url, true)
	end)
	if content and content ~= "" then
		local fn = loadstring(content)
		if fn then return fn() end
	end

	if fallbackFile then
		pcall(function()
			if readfile and isfile and isfile(fallbackFile) then
				content = readfile(fallbackFile)
			end
		end)
		if content and content ~= "" then
			local fn = loadstring(content)
			if fn then return fn() end
		end
	end

	return nil
end

local function loadFluent()
	local lib = fetchScript(
		"https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceUI.lua",
		"SubstanceUI.lua"
	)
	if not lib then
		lib = fetchScript(
			"https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
			"SubstanceUI.lua"
		)
	end
	return lib
end

-- load module system
local SubstanceModules = fetchScript(
	"https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceModules.lua",
	"SubstanceModules.lua"
)

-- key system (fluent ui based)
local VALID_KEY = "releasehellyeah"
local DISCORD_INVITE = "https://discord.gg/substance"

if not _G.SubstanceKeyValid then
	local KeyFluent = loadFluent()
	if not KeyFluent then
		error("[Substance] Failed to load Fluent UI library for key system")
	end

	local KeyWindow = KeyFluent:CreateWindow({
		Title = "Substance",
		SubTitle = "Key System",
		TabWidth = 140,
		Size = UDim2.fromOffset(460, 310),
		Acrylic = true,
		Theme = "Amethyst",
		MinimizeKey = Enum.KeyCode.End,
	})

	local keyTab = KeyWindow:AddTab({ Title = "Access", Icon = "key" })

	keyTab:AddSection("Verification")
	keyTab:AddParagraph({
		Title = "Welcome to Substance",
		Content = "Enter your key below to unlock the hub.\nJoin our Discord server to get the key.",
	})

	local enteredKey = ""
	keyTab:AddInput("KeyInput", {
		Title = "Key",
		Default = "",
		Placeholder = "Paste key here...",
		Callback = function(v)
			enteredKey = v
		end,
	})

	local keyVerified = false

	keyTab:AddButton({
		Title = "Submit Key",
		Description = "Verifies your key and loads the hub",
		Callback = function()
			local clean = enteredKey:gsub("%s+", "")
			if clean == VALID_KEY then
				_G.SubstanceKeyValid = true
				keyVerified = true
				KeyFluent:Notify({
					Title = "Key Accepted",
					Content = "Loading Substance Hub...",
					Duration = 2,
				})
				task.wait(0.4)
				KeyFluent:Destroy()
			else
				KeyFluent:Notify({
					Title = "Invalid Key",
					Content = "Incorrect key. Check our Discord for the key.",
					Duration = 3,
				})
			end
		end,
	})

	keyTab:AddButton({
		Title = "Join Discord",
		Description = "Copies our Discord invite to your clipboard",
		Callback = function()
			pcall(function()
				setclipboard(DISCORD_INVITE)
			end)
			KeyFluent:Notify({
				Title = "Discord Invite Copied",
				Content = "Copied " .. DISCORD_INVITE .. " to clipboard!",
				Duration = 4,
			})
		end,
	})

	-- Select tab so it is open and visible immediately
	KeyWindow:SelectTab(1)

	repeat task.wait(0.1) until keyVerified
end

-- now load fresh fluent instance for the main hub
local Fluent = loadFluent()
if not Fluent then
	error("[Substance] Failed to load Fluent UI library for main hub")
end

-- game detection
local mps = game:GetService("MarketplaceService")
local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local lp = plrs.LocalPlayer
local gameId = game.PlaceId
local gameName = "Universal"

pcall(function()
	local info = mps:GetProductInfo(gameId)
	if info and info.Name then gameName = info.Name end
end)

local REPO = "https://raw.githubusercontent.com/LilacTheNobody/Substance/main/"

local gameRegistry = {
	[142823291] = {
		Name = "Murder Mystery 2",
		ModuleUrl = REPO .. "modules/mm2.lua",
		ModuleFile = "modules/mm2.lua",
	},
	[3351327787] = {
		Name = "Murder Mystery 2 (Trading)",
		ModuleUrl = REPO .. "modules/mm2.lua",
		ModuleFile = "modules/mm2.lua",
	},
}

local currentGame = gameRegistry[gameId]
if currentGame then
	gameName = currentGame.Name
end

-- create main acrylic window (acrylic blur permanently enabled, theme locked to Amethyst)
local Window = Fluent:CreateWindow({
	Title = "Substance",
	SubTitle = gameName,
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 470),
	Acrylic = true,
	Theme = "Amethyst",
	MinimizeKey = Enum.KeyCode.LeftControl,
})

Fluent:Notify({
	Title = "Substance",
	Content = "Loaded in " .. gameName,
	Duration = 4,
})

-- movement & character controller
local charMods = {
	speed = 16,
	speedEnabled = false,
	jump = 50,
	jumpEnabled = false,
	noclip = false,
	antiFling = false,
	antiVoid = false,
	infJump = false,
	flying = false,
	flySpeed = 50,
	xray = false,
}

local noclipConn = nil
local antiFlingConn = nil
local antiVoidConn = nil
local infJumpConn = nil
local voidPlatform = nil
local lastSafeCFrame = nil
local lastVoidSave = 0
local flyBg = nil
local flyBv = nil

local function applySpeedAndJump()
	pcall(function()
		if lp.Character and lp.Character:FindFirstChild("Humanoid") then
			local hum = lp.Character.Humanoid
			local targetSpeed = charMods.speedEnabled and charMods.speed or 16
			local targetJump = charMods.jumpEnabled and charMods.jump or 50
			if hum.WalkSpeed ~= targetSpeed then
				hum.WalkSpeed = targetSpeed
			end
			if hum.JumpPower ~= targetJump then
				hum.JumpPower = targetJump
			end
		end
	end)
end

local function hookCharacter(ch)
	local hum = ch:WaitForChild("Humanoid", 5)
	if hum then
		hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			local targetSpeed = charMods.speedEnabled and charMods.speed or 16
			if hum.WalkSpeed ~= targetSpeed then
				hum.WalkSpeed = targetSpeed
			end
		end)
		hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
			local targetJump = charMods.jumpEnabled and charMods.jump or 50
			if hum.JumpPower ~= targetJump then
				hum.JumpPower = targetJump
			end
		end)
	end
	applySpeedAndJump()
end

if lp.Character then hookCharacter(lp.Character) end
lp.CharacterAdded:Connect(function(ch)
	hookCharacter(ch)
end)
rs.Heartbeat:Connect(applySpeedAndJump)

-- ground tracking for anti-void (records any solid ground position)
rs.Heartbeat:Connect(function()
	pcall(function()
		if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character:FindFirstChild("Humanoid") then
			local hum = lp.Character.Humanoid
			local hrp = lp.Character.HumanoidRootPart
			if hum.Health > 0 and hum.FloorMaterial ~= Enum.Material.Air then
				lastSafeCFrame = hrp.CFrame
			end
		end
	end)
end)

-- reliable noclip (disables collisions across character on Stepped, cleanly restored on disable)
local function setNoclip(v)
	charMods.noclip = v
	if v then
		if not noclipConn then
			noclipConn = rs.Stepped:Connect(function()
				if not charMods.noclip then return end
				if lp.Character then
					pcall(function()
						for _, part in ipairs(lp.Character:GetDescendants()) do
							if part:IsA("BasePart") and part.CanCollide then
								part.CanCollide = false
							end
						end
					end)
				end
			end)
		end
	else
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		-- restore full collision across all parts except HumanoidRootPart
		pcall(function()
			if lp.Character then
				for _, part in ipairs(lp.Character:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
						part.CanCollide = true
					end
				end
			end
		end)
	end
end

-- anti-fling (disables collisions with other players and absorbs extreme impulse)
local function setAntiFling(v)
	charMods.antiFling = v
	if v then
		if not antiFlingConn then
			antiFlingConn = rs.Stepped:Connect(function()
				if not charMods.antiFling then return end
				pcall(function()
					for _, p in ipairs(plrs:GetPlayers()) do
						if p ~= lp and p.Character then
							for _, part in ipairs(p.Character:GetChildren()) do
								if part:IsA("BasePart") then
									part.CanCollide = false
								end
							end
						end
					end

					if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
						local hrp = lp.Character.HumanoidRootPart
						if hrp.AssemblyLinearVelocity.Magnitude > 75 then
							hrp.AssemblyLinearVelocity = Vector3.zero
						end
						if hrp.AssemblyAngularVelocity.Magnitude > 75 then
							hrp.AssemblyAngularVelocity = Vector3.zero
						end
					end
				end)
			end)
		end
	else
		if antiFlingConn then
			antiFlingConn:Disconnect()
			antiFlingConn = nil
		end
	end
end

-- reliable anti-void (catches player as soon as falling into the void on any map, spawns platform, and teleports back)
local function setAntiVoid(v)
	charMods.antiVoid = v
	if v then
		if not antiVoidConn then
			antiVoidConn = rs.Heartbeat:Connect(function()
				if not charMods.antiVoid then return end
				pcall(function()
					if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character:FindFirstChild("Humanoid") then
						local hrp = lp.Character.HumanoidRootPart
						local hum = lp.Character.Humanoid
						if hum.Health <= 0 then return end

						local fallenLimit = workspace.FallenPartsDestroyHeight
						if fallenLimit ~= fallenLimit or fallenLimit < -50000 or fallenLimit > 50000 then
							fallenLimit = -500
						end

						local isVoid = false
						-- check 1: approaching Roblox kill plane
						if hrp.Position.Y <= (fallenLimit + 45) then
							isVoid = true
						end

						-- check 2: fallen well below last recorded safe ground with no part beneath
						if not isVoid and lastSafeCFrame and (lastSafeCFrame.Position.Y - hrp.Position.Y) > 40 then
							local rayParams = RaycastParams.new()
							rayParams.FilterType = RaycastFilterType.Exclude
							local ignoreList = { lp.Character }
							if voidPlatform then table.insert(ignoreList, voidPlatform) end
							rayParams.FilterDescendantsInstances = ignoreList

							local rayResult = workspace:Raycast(hrp.Position, Vector3.new(0, -90, 0), rayParams)
							if not rayResult then
								isVoid = true
							end
						end

						-- check 3: low negative altitude without any ground
						if not isVoid and hrp.Position.Y < -35 then
							local rayParams = RaycastParams.new()
							rayParams.FilterType = RaycastFilterType.Exclude
							local ignoreList = { lp.Character }
							if voidPlatform then table.insert(ignoreList, voidPlatform) end
							rayParams.FilterDescendantsInstances = ignoreList

							local rayResult = workspace:Raycast(hrp.Position, Vector3.new(0, -100, 0), rayParams)
							if not rayResult then
								isVoid = true
							end
						end

						if isVoid then
							local now = tick()
							if now - lastVoidSave > 1.2 then
								lastVoidSave = now

								-- nullify physics velocity immediately
								hrp.AssemblyLinearVelocity = Vector3.zero
								hrp.AssemblyAngularVelocity = Vector3.zero

								local targetCf = lastSafeCFrame and (lastSafeCFrame + Vector3.new(0, 3.5, 0))
								if not targetCf then
									targetCf = CFrame.new(hrp.Position.X, 10, hrp.Position.Z)
								end

								-- create or move neon purple safe platform
								if not voidPlatform or not voidPlatform.Parent then
									voidPlatform = Instance.new("Part")
									voidPlatform.Name = "SubstanceVoidPlatform"
									voidPlatform.Size = Vector3.new(40, 2, 40)
									voidPlatform.Anchored = true
									voidPlatform.CanCollide = true
									voidPlatform.Material = Enum.Material.Neon
									voidPlatform.Color = Color3.fromRGB(138, 43, 226)
									voidPlatform.Parent = workspace
								end

								voidPlatform.CFrame = CFrame.new(targetCf.Position.X, targetCf.Position.Y - 3, targetCf.Position.Z)

								for _ = 1, 6 do
									hrp.AssemblyLinearVelocity = Vector3.zero
									hrp.AssemblyAngularVelocity = Vector3.zero
									hrp.CFrame = targetCf
									task.wait(0.02)
								end

								Fluent:Notify({
									Title = "Anti Void",
									Content = "Saved from void! Restored to safe ground.",
									Duration = 3,
								})
							end
						end
					end
				end)
			end)
		end
	else
		if antiVoidConn then
			antiVoidConn:Disconnect()
			antiVoidConn = nil
		end
		if voidPlatform then
			pcall(function() voidPlatform:Destroy() end)
			voidPlatform = nil
		end
	end
end

-- fly system (wasd + space/shift + camera orientation)
local function setFly(v)
	charMods.flying = v
	if v then
		local ch = lp.Character
		if not ch then return end
		local hrp = ch:FindFirstChild("HumanoidRootPart")
		local hum = ch:FindFirstChild("Humanoid")
		if not hrp or not hum then return end

		if flyBg then flyBg:Destroy() end
		if flyBv then flyBv:Destroy() end

		flyBg = Instance.new("BodyGyro")
		flyBg.P = 9e4
		flyBg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
		flyBg.cframe = hrp.CFrame
		flyBg.Parent = hrp

		flyBv = Instance.new("BodyVelocity")
		flyBv.velocity = Vector3.new(0, 0.1, 0)
		flyBv.maxForce = Vector3.new(9e9, 9e9, 9e9)
		flyBv.Parent = hrp

		task.spawn(function()
			while charMods.flying and lp.Character and hrp.Parent and hum.Parent do
				hum.PlatformStand = true
				local cam = workspace.CurrentCamera
				local move = Vector3.zero

				if uis:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
				if uis:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
				if uis:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
				if uis:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
				if uis:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
				if uis:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end

				if move.Magnitude > 0 then
					flyBv.velocity = move.Unit * charMods.flySpeed
				else
					flyBv.velocity = Vector3.zero
				end
				flyBg.cframe = cam.CFrame
				rs.Heartbeat:Wait()
			end
			if flyBg then flyBg:Destroy(); flyBg = nil end
			if flyBv then flyBv:Destroy(); flyBv = nil end
			if lp.Character and lp.Character:FindFirstChild("Humanoid") then
				lp.Character.Humanoid.PlatformStand = false
			end
		end)
	else
		if flyBg then flyBg:Destroy(); flyBg = nil end
		if flyBv then flyBv:Destroy(); flyBv = nil end
		if lp.Character and lp.Character:FindFirstChild("Humanoid") then
			lp.Character.Humanoid.PlatformStand = false
		end
	end
end

-- xray (makes map walls transparent)
local function setXray(v)
	charMods.xray = v
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and not part.Parent:FindFirstChild("Humanoid") and not (part.Parent.Parent and part.Parent.Parent:FindFirstChild("Humanoid")) then
			if v then
				if not part:GetAttribute("SubstanceOrigTrans") then
					part:SetAttribute("SubstanceOrigTrans", part.LocalTransparencyModifier)
				end
				part.LocalTransparencyModifier = 0.75
			else
				local orig = part:GetAttribute("SubstanceOrigTrans") or 0
				part.LocalTransparencyModifier = orig
			end
		end
	end
end

-- home tab
local homeTab = Window:AddTab({ Title = "Home", Icon = "home" })

homeTab:AddSection("Session")
homeTab:AddParagraph({
	Title = "Player Information",
	Content = "User: " .. (lp and lp.Name or "Player") .. "\nGame: " .. gameName .. "\nPlace ID: " .. tostring(gameId),
})

homeTab:AddSection("Server Actions")
homeTab:AddButton({
	Title = "Rejoin Server",
	Description = "Reconnects to current server",
	Callback = function()
		pcall(function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(gameId, game.JobId, lp)
		end)
	end,
})

homeTab:AddButton({
	Title = "Server Hop",
	Description = "Finds another active server",
	Callback = function()
		pcall(function()
			game:GetService("TeleportService"):Teleport(gameId, lp)
		end)
	end,
})

homeTab:AddButton({
	Title = "Copy Place ID",
	Description = "Copies Place ID to clipboard",
	Callback = function()
		pcall(function() setclipboard(tostring(gameId)) end)
		Fluent:Notify({ Title = "Copied", Content = "Place ID copied to clipboard", Duration = 2 })
	end,
})

-- player tab
local playerTab = Window:AddTab({ Title = "Player", Icon = "user" })

playerTab:AddSection("Movement")
local speedToggle = playerTab:AddToggle("EnableSpeed", {
	Title = "Enable Custom Speed",
	Default = false,
	Callback = function(v)
		charMods.speedEnabled = v
		applySpeedAndJump()
	end,
})

playerTab:AddSlider("WalkSpeed", {
	Title = "WalkSpeed",
	Min = 16,
	Max = 250,
	Default = 16,
	Rounding = 1,
	Callback = function(v)
		charMods.speed = v
		applySpeedAndJump()
	end,
})

local jumpToggle = playerTab:AddToggle("EnableJump", {
	Title = "Enable Custom Jump",
	Default = false,
	Callback = function(v)
		charMods.jumpEnabled = v
		applySpeedAndJump()
	end,
})

playerTab:AddSlider("JumpPower", {
	Title = "JumpPower",
	Min = 50,
	Max = 350,
	Default = 50,
	Rounding = 1,
	Callback = function(v)
		charMods.jump = v
		applySpeedAndJump()
	end,
})

playerTab:AddToggle("InfiniteJump", {
	Title = "Infinite Jump",
	Default = false,
	Callback = function(v)
		charMods.infJump = v
		if v and not infJumpConn then
			infJumpConn = uis.JumpRequest:Connect(function()
				if charMods.infJump and lp.Character and lp.Character:FindFirstChild("Humanoid") then
					pcall(function()
						lp.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end)
				end
			end)
		elseif not v and infJumpConn then
			infJumpConn:Disconnect()
			infJumpConn = nil
		end
	end,
})

local noclipToggle = playerTab:AddToggle("Noclip", {
	Title = "Noclip",
	Description = "Walk through any wall or obstacle [Key: R]",
	Default = false,
	Callback = function(v)
		setNoclip(v)
	end,
})

playerTab:AddSection("Flight & Vision")
local flyToggle = playerTab:AddToggle("Fly", {
	Title = "Fly",
	Description = "Fly freely with WASD, Space (Up), and Shift (Down) [Key: F]",
	Default = false,
	Callback = function(v)
		setFly(v)
	end,
})

playerTab:AddSlider("FlySpeed", {
	Title = "Fly Speed",
	Min = 10,
	Max = 200,
	Default = 50,
	Rounding = 1,
	Callback = function(v)
		charMods.flySpeed = v
	end,
})

local xrayToggle = playerTab:AddToggle("Xray", {
	Title = "X-Ray",
	Description = "Makes all map walls and obstacles semi-transparent [Key: X]",
	Default = false,
	Callback = function(v)
		setXray(v)
	end,
})

playerTab:AddSection("Defense")
local antiFlingToggle = playerTab:AddToggle("AntiFling", {
	Title = "Anti Fling",
	Description = "Prevents other players from pushing or flinging you",
	Default = false,
	Callback = function(v)
		setAntiFling(v)
	end,
})

local antiVoidToggle = playerTab:AddToggle("AntiVoid", {
	Title = "Anti Void",
	Description = "Catches you if you fall off any map and teleports you back to ground [Key: V]",
	Default = false,
	Callback = function(v)
		setAntiVoid(v)
	end,
})

playerTab:AddSection("Trolling")
local selectedFlingTarget = ""
local flingDropdown = nil

local function getPlayerNames()
	local names = {}
	for _, p in ipairs(plrs:GetPlayers()) do
		if p ~= lp then
			table.insert(names, p.DisplayName .. " (@" .. p.Name .. ")")
		end
	end
	return names
end

flingDropdown = playerTab:AddDropdown("FlingTarget", {
	Title = "Target Player",
	Values = getPlayerNames(),
	Multi = false,
	Default = "",
	Callback = function(v)
		selectedFlingTarget = v or ""
	end,
})

playerTab:AddButton({
	Title = "Refresh Player List",
	Callback = function()
		if flingDropdown then
			flingDropdown:SetValues(getPlayerNames())
		end
	end,
})

local function flingPlayer(target)
	if not target or not target.Character then return false end
	local ch = lp.Character
	local tch = target.Character
	if not ch or not tch then return false end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local thrp = tch:FindFirstChild("HumanoidRootPart")
	if not hrp or not thrp then return false end

	local savedPos = hrp.CFrame

	local bav = Instance.new("BodyAngularVelocity")
	bav.AngularVelocity = Vector3.new(99999, 99999, 99999)
	bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bav.P = math.huge
	bav.Parent = hrp

	local t0 = tick()
	while tick() - t0 < 1.4 and thrp.Parent do
		hrp.CFrame = thrp.CFrame
		task.wait()
	end
	bav:Destroy()

	for _ = 1, 8 do
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = savedPos
		task.wait(0.03)
	end
	return true
end

playerTab:AddButton({
	Title = "Fling Target",
	Description = "Launches target player and teleports you back to safety",
	Callback = function()
		if selectedFlingTarget == "" then
			Fluent:Notify({ Title = "Fling", Content = "Select a target first!", Duration = 2 })
			return
		end

		local targetUser = selectedFlingTarget:match("@([%w_]+)")
		local target = nil
		for _, p in ipairs(plrs:GetPlayers()) do
			if p.Name == targetUser or p.DisplayName == selectedFlingTarget then
				target = p
				break
			end
		end

		if not target then
			Fluent:Notify({ Title = "Fling", Content = "Target player not found", Duration = 2 })
			return
		end

		task.spawn(function()
			flingPlayer(target)
			Fluent:Notify({ Title = "Fling", Content = "Fling finished! Returned to safe position.", Duration = 2 })
		end)
	end,
})

playerTab:AddButton({
	Title = "Fling All Players",
	Description = "Sequentially flings every other player in the server",
	Callback = function()
		task.spawn(function()
			local origPos = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character.HumanoidRootPart.CFrame
			for _, p in ipairs(plrs:GetPlayers()) do
				if p ~= lp and p.Character then
					flingPlayer(p)
					task.wait(0.1)
				end
			end
			if origPos and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
				lp.Character.HumanoidRootPart.CFrame = origPos
			end
			Fluent:Notify({ Title = "Fling All", Content = "Fling all completed!", Duration = 3 })
		end)
	end,
})

-- keybind hotkey listener (won't trigger while typing in chat or textboxes)
uis.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or uis:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.F then
		setFly(not charMods.flying)
		if flyToggle then pcall(function() flyToggle:SetValue(charMods.flying) end) end
	elseif input.KeyCode == Enum.KeyCode.R then
		setNoclip(not charMods.noclip)
		if noclipToggle then pcall(function() noclipToggle:SetValue(charMods.noclip) end) end
	elseif input.KeyCode == Enum.KeyCode.X then
		setXray(not charMods.xray)
		if xrayToggle then pcall(function() xrayToggle:SetValue(charMods.xray) end) end
	elseif input.KeyCode == Enum.KeyCode.V then
		setAntiVoid(not charMods.antiVoid)
		if antiVoidToggle then pcall(function() antiVoidToggle:SetValue(charMods.antiVoid) end) end
	end
end)

-- load game specific module
if currentGame and SubstanceModules then
	local modEntry = SubstanceModules:LoadFromURL(currentGame.ModuleUrl)
	if not modEntry and currentGame.ModuleFile then
		modEntry = SubstanceModules:LoadFromFile(currentGame.ModuleFile)
	end
	if modEntry then
		SubstanceModules:BuildTab(modEntry, Window, Fluent)
	end
end

-- settings tab (acrylic blur permanently on, theme locked, discord button included)
local settingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })

settingsTab:AddSection("Appearance")
settingsTab:AddParagraph({
	Title = "Theme & Acrylic Glass",
	Content = "Substance is permanently styled with the Amethyst Acrylic aesthetic.",
})

settingsTab:AddSection("Community")
settingsTab:AddButton({
	Title = "Join Discord",
	Description = "Copies official Discord server link",
	Callback = function()
		pcall(function() setclipboard(DISCORD_INVITE) end)
		Fluent:Notify({
			Title = "Discord Invite",
			Content = "Copied " .. DISCORD_INVITE .. " to clipboard!",
			Duration = 4,
		})
	end,
})

settingsTab:AddSection("Hub Management")
settingsTab:AddParagraph({
	Title = "Hotkey",
	Content = "Press Left Control to toggle interface visibility",
})

settingsTab:AddButton({
	Title = "Unload Hub",
	Description = "Closes Substance and cleans up all active scripts",
	Callback = function()
		if SubstanceModules then
			SubstanceModules:UnloadAll()
		end
		setNoclip(false)
		setFly(false)
		setXray(false)
		setAntiFling(false)
		setAntiVoid(false)
		if infJumpConn then infJumpConn:Disconnect() end
		Window:Destroy()
	end,
})

-- Open Home tab by default upon window creation
Window:SelectTab(1)
