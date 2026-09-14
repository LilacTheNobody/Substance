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

-- create main acrylic window (theme locked to Amethyst)
local Window = Fluent:CreateWindow({
	Title = "Substance",
	SubTitle = gameName,
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 460),
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
	jump = 50,
	noclip = false,
	antiFling = false,
	antiVoid = false,
	infJump = false,
}

local noclipConn = nil
local antiFlingConn = nil
local antiVoidConn = nil
local infJumpConn = nil
local voidPlatform = nil

local function applySpeedAndJump()
	pcall(function()
		if lp.Character and lp.Character:FindFirstChild("Humanoid") then
			local hum = lp.Character.Humanoid
			if charMods.speed ~= 16 and hum.WalkSpeed ~= charMods.speed then
				hum.WalkSpeed = charMods.speed
			end
			if charMods.jump ~= 50 and hum.JumpPower ~= charMods.jump then
				hum.JumpPower = charMods.jump
			end
		end
	end)
end

local function hookCharacter(ch)
	local hum = ch:WaitForChild("Humanoid", 5)
	if hum then
		hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if charMods.speed ~= 16 and hum.WalkSpeed ~= charMods.speed then
				hum.WalkSpeed = charMods.speed
			end
		end)
		hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
			if charMods.jump ~= 50 and hum.JumpPower ~= charMods.jump then
				hum.JumpPower = charMods.jump
			end
		end)
	end
	applySpeedAndJump()
end

if lp.Character then hookCharacter(lp.Character) end
lp.CharacterAdded:Connect(hookCharacter)
rs.Heartbeat:Connect(applySpeedAndJump)

-- working noclip (walk through any wall/barrier with floor raycast protection)
local function setNoclip(v)
	charMods.noclip = v
	if v then
		if not noclipConn then
			noclipConn = rs.Stepped:Connect(function()
				if not charMods.noclip then return end
				if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character:FindFirstChild("Humanoid") then
					local hrp = lp.Character.HumanoidRootPart
					local hum = lp.Character.Humanoid

					-- disable collisions on all character parts to walk through all walls
					for _, part in ipairs(lp.Character:GetDescendants()) do
						if part:IsA("BasePart") and part.CanCollide then
							part.CanCollide = false
						end
					end

					-- floor check: prevent sinking/falling through floor
					local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -hum.HipHeight - 2.5, 0))
					if ray and ray.Instance and not ray.Instance:IsDescendantOf(lp.Character) then
						local floorY = ray.Position.Y + hum.HipHeight + 2.4
						if hrp.Position.Y < floorY then
							hrp.CFrame = CFrame.new(hrp.Position.X, floorY, hrp.Position.Z)
							if hrp.AssemblyLinearVelocity.Y < 0 then
								hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
							end
						end
					end
				end
			end)
		end
	else
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		-- restore full collision across all parts
		pcall(function()
			if lp.Character then
				for _, part in ipairs(lp.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
			end
		end)
	end
end

-- anti-fling (collides with nothing and absorbs extreme impulse)
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

-- anti-void (spawns safe platform if you fall into void)
local function setAntiVoid(v)
	charMods.antiVoid = v
	if v then
		if not antiVoidConn then
			antiVoidConn = rs.Heartbeat:Connect(function()
				if not charMods.antiVoid then return end
				pcall(function()
					if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
						local hrp = lp.Character.HumanoidRootPart
						local fallenLimit = workspace.FallenPartsDestroyHeight
						if fallenLimit == 0/0 or fallenLimit < -5000 then
							fallenLimit = -250
						end
						local voidThreshold = fallenLimit + 65

						if hrp.Position.Y < voidThreshold then
							hrp.AssemblyLinearVelocity = Vector3.zero
							hrp.AssemblyAngularVelocity = Vector3.zero

							if not voidPlatform or not voidPlatform.Parent then
								voidPlatform = Instance.new("Part")
								voidPlatform.Name = "SubstanceVoidPlatform"
								voidPlatform.Size = Vector3.new(24, 2, 24)
								voidPlatform.Anchored = true
								voidPlatform.CanCollide = true
								voidPlatform.Material = Enum.Material.Neon
								voidPlatform.Color = Color3.fromRGB(138, 43, 226)
								voidPlatform.Parent = workspace
							end

							local safeY = voidThreshold + 15
							voidPlatform.Position = Vector3.new(hrp.Position.X, safeY - 1, hrp.Position.Z)
							hrp.CFrame = CFrame.new(hrp.Position.X, safeY + 3.5, hrp.Position.Z)

							Fluent:Notify({
								Title = "Anti Void",
								Content = "Saved from void! Platform created.",
								Duration = 3,
							})
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
playerTab:AddSlider("WalkSpeed", {
	Title = "WalkSpeed",
	Min = 16,
	Max = 200,
	Default = 16,
	Rounding = 1,
	Callback = function(v)
		charMods.speed = v
		applySpeedAndJump()
	end,
})

playerTab:AddSlider("JumpPower", {
	Title = "JumpPower",
	Min = 50,
	Max = 300,
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

playerTab:AddToggle("Noclip", {
	Title = "Noclip",
	Description = "Walk through any wall or obstacle with floor protection",
	Default = false,
	Callback = function(v)
		setNoclip(v)
	end,
})

playerTab:AddSection("Defense")
playerTab:AddToggle("AntiFling", {
	Title = "Anti Fling",
	Description = "Prevents other players from pushing or flinging you",
	Default = false,
	Callback = function(v)
		setAntiFling(v)
	end,
})

playerTab:AddToggle("AntiVoid", {
	Title = "Anti Void",
	Description = "Spawns a platform beneath you if you fall into the void",
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

		if not target or not target.Character then
			Fluent:Notify({ Title = "Fling", Content = "Target character not found", Duration = 2 })
			return
		end

		local ch = lp.Character
		local tch = target.Character
		if not ch or not tch then return end
		local hrp = ch:FindFirstChild("HumanoidRootPart")
		local thrp = tch:FindFirstChild("HumanoidRootPart")
		if not hrp or not thrp then return end

		-- Save position before flinging
		local savedPos = hrp.CFrame

		local bav = Instance.new("BodyAngularVelocity")
		bav.AngularVelocity = Vector3.new(99999, 99999, 99999)
		bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bav.P = math.huge
		bav.Parent = hrp

		task.spawn(function()
			local t0 = tick()
			while tick() - t0 < 1.5 and thrp.Parent do
				hrp.CFrame = thrp.CFrame
				task.wait()
			end
			bav:Destroy()

			-- Multi-frame momentum kill and return to saved position
			for _ = 1, 8 do
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				hrp.CFrame = savedPos
				task.wait(0.03)
			end

			Fluent:Notify({ Title = "Fling", Content = "Fling finished! Teleported back to your spot.", Duration = 2 })
		end)
	end,
})

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

-- settings tab (theme locked, discord button included)
local settingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })

settingsTab:AddSection("Appearance")
settingsTab:AddParagraph({
	Title = "Theme Locked",
	Content = "Substance is permanently tailored with the Amethyst Acrylic aesthetic.",
})

settingsTab:AddToggle("AcrylicToggle", {
	Title = "Acrylic Blur",
	Default = true,
	Callback = function(v)
		if Fluent.ToggleAcrylic then
			Fluent:ToggleAcrylic(v)
		end
	end,
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
		setAntiFling(false)
		setAntiVoid(false)
		if infJumpConn then infJumpConn:Disconnect() end
		Window:Destroy()
	end,
})

-- Open Home tab by default upon window creation
Window:SelectTab(1)
