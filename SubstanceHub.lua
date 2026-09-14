-- Substance Hub
-- universal game script hub with module loading

if not game:IsLoaded() then
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "Substance",
		Text = "Waiting for game to load...",
		Duration = 5
	})
	game.Loaded:Wait()
end

-- key system (saved in _G so it persists within session)
local VALID_KEY = "releasehellyeah"

if not _G.SubstanceKeyValid then
	local plr = game:GetService("Players").LocalPlayer
	local pg = plr:WaitForChild("PlayerGui")

	local sg = Instance.new("ScreenGui")
	sg.Name = "SubstanceKey"
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.ResetOnSpawn = false
	sg.Parent = pg

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(360, 200)
	box.Position = UDim2.new(0.5, -180, 0.5, -100)
	box.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
	box.BorderSizePixel = 0
	box.Parent = sg

	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
	local s = Instance.new("UIStroke", box)
	s.Color = Color3.fromRGB(138, 43, 226)
	s.Thickness = 2

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.fromOffset(0, 15)
	title.BackgroundTransparency = 1
	title.Text = "Substance"
	title.TextColor3 = Color3.fromRGB(200, 140, 255)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.Parent = box

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.Position = UDim2.fromOffset(0, 50)
	sub.BackgroundTransparency = 1
	sub.Text = "Enter your key to continue"
	sub.TextColor3 = Color3.fromRGB(140, 120, 170)
	sub.TextSize = 13
	sub.Font = Enum.Font.Gotham
	sub.Parent = box

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(0.8, 0, 0, 36)
	input.Position = UDim2.new(0.1, 0, 0, 85)
	input.BackgroundColor3 = Color3.fromRGB(30, 24, 48)
	input.BorderSizePixel = 0
	input.Text = ""
	input.PlaceholderText = "paste key here..."
	input.PlaceholderColor3 = Color3.fromRGB(90, 75, 120)
	input.TextColor3 = Color3.fromRGB(230, 220, 255)
	input.TextSize = 14
	input.Font = Enum.Font.Gotham
	input.ClearTextOnFocus = false
	input.Parent = box
	Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)
	local is = Instance.new("UIStroke", input)
	is.Color = Color3.fromRGB(60, 45, 90)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.8, 0, 0, 36)
	btn.Position = UDim2.new(0.1, 0, 0, 135)
	btn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
	btn.BorderSizePixel = 0
	btn.Text = "Submit"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.Parent = box
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 20)
	status.Position = UDim2.fromOffset(0, 175)
	status.BackgroundTransparency = 1
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(255, 80, 80)
	status.TextSize = 12
	status.Font = Enum.Font.Gotham
	status.Parent = box

	local keyOk = false

	btn.MouseButton1Click:Connect(function()
		local entered = input.Text:gsub("%s+", "")
		if entered == VALID_KEY then
			keyOk = true
			_G.SubstanceKeyValid = true
			status.Text = "Key accepted!"
			status.TextColor3 = Color3.fromRGB(80, 220, 120)
			task.wait(0.5)
			sg:Destroy()
		else
			status.Text = "Invalid key"
			status.TextColor3 = Color3.fromRGB(255, 80, 80)
			input.Text = ""
		end
	end)

	repeat task.wait(0.1) until keyOk
end

-- load libraries
local function loadLib(name, url)
	local ok, result = pcall(function()
		if readfile then return loadstring(readfile(name .. ".lua"))() end
	end)
	if ok and result then return result end
	if url then
		local ok2, result2 = pcall(function()
			return loadstring(game:HttpGet(url, true))()
		end)
		if ok2 and result2 then return result2 end
	end
	error("[Substance] cant load: " .. name)
end

local SubstanceUI = loadLib("SubstanceUI",
	"https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceUI.lua")
local SubstanceModules = loadLib("SubstanceModules",
	"https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceModules.lua")

-- detect game
local mps = game:GetService("MarketplaceService")
local plrs = game:GetService("Players")
local lp = plrs.LocalPlayer

local gameId = game.PlaceId
local gameName = "Unknown Game"

pcall(function()
	local info = mps:GetProductInfo(gameId)
	if info and info.Name then gameName = info.Name end
end)

-- game registry - add your games here
local REPO = "https://raw.githubusercontent.com/LilacTheNobody/Substance/main/"

local games = {
	[142823291] = {
		Name = "Murder Mystery 2",
		Category = "Horror",
		Modules = {
			{ Type = "url", Path = REPO .. "modules/mm2.lua" },
		},
	},
}

local gameInfo = games[gameId]
if gameInfo then gameName = gameInfo.Name end
local category = gameInfo and gameInfo.Category or "Universal"

-- create window
local Window = SubstanceUI:CreateWindow({
	Title = "Substance",
	Subtitle = gameName .. "  |  " .. tostring(gameId),
	Size = UDim2.fromOffset(580, 420),
})

SubstanceUI:Notify({
	Title = "Substance",
	Description = "Loaded in: " .. gameName,
	Duration = 5,
	Color = SubstanceUI.Theme.Primary,
})

-- home tab
local home = Window:CreateTab({ Name = "Home", Icon = "rbxassetid://7733960981" })

home:CreateSection({ Name = "Welcome" })
home:CreateLabel({ Text = "Welcome, " .. (lp and lp.Name or "User") })
home:CreateLabel({ Text = "Game: " .. gameName })
home:CreateLabel({ Text = "Category: " .. category })
home:CreateLabel({ Text = "Place ID: " .. tostring(gameId) })
home:CreateSeparator()

home:CreateSection({ Name = "Quick Actions" })
home:CreateButton({
	Name = "Rejoin Server",
	Callback = function()
		pcall(function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(gameId, game.JobId, lp)
		end)
	end,
})
home:CreateButton({
	Name = "Server Hop",
	Callback = function()
		pcall(function()
			game:GetService("TeleportService"):Teleport(gameId, lp)
		end)
	end,
})
home:CreateButton({
	Name = "Copy Place ID",
	Callback = function()
		pcall(setclipboard, tostring(gameId))
		SubstanceUI:Notify({ Title = "Copied", Description = "Place ID copied", Duration = 2 })
	end,
})

-- player tab
local player = Window:CreateTab({ Name = "Player", Icon = "rbxassetid://7733658504" })

player:CreateSection({ Name = "Character" })
player:CreateSlider({
	Name = "Walk Speed", Min = 16, Max = 500, Default = 16,
	Callback = function(v) pcall(function() lp.Character.Humanoid.WalkSpeed = v end) end,
})
player:CreateSlider({
	Name = "Jump Power", Min = 50, Max = 500, Default = 50,
	Callback = function(v) pcall(function() lp.Character.Humanoid.JumpPower = v end) end,
})

local infJumpConn = nil
player:CreateToggle({
	Name = "Infinite Jump", Default = false,
	Callback = function(v)
		if v then
			infJumpConn = game:GetService("UserInputService").JumpRequest:Connect(function()
				pcall(function() lp.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
			end)
		else
			if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
		end
	end,
})

local noclipOn = false
local noclipConn = nil
player:CreateToggle({
	Name = "Noclip", Default = false,
	Callback = function(v)
		noclipOn = v
		if v then
			noclipConn = game:GetService("RunService").Stepped:Connect(function()
				if noclipOn then
					pcall(function()
						for _, p in ipairs(lp.Character:GetDescendants()) do
							if p:IsA("BasePart") then p.CanCollide = false end
						end
					end)
				end
			end)
		else
			if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
		end
	end,
})

player:CreateSeparator()
player:CreateSection({ Name = "Teleport" })
player:CreateTextbox({
	Name = "TP to Player", Placeholder = "Username...",
	Callback = function(text)
		pcall(function()
			local target = plrs:FindFirstChild(text)
			if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
				lp.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
			end
		end)
	end,
})

-- load game modules
if gameInfo and gameInfo.Modules then
	for _, def in ipairs(gameInfo.Modules) do
		local entry
		if def.Type == "url" then
			entry = SubstanceModules:LoadFromURL(def.Path)
		elseif def.Type == "file" then
			entry = SubstanceModules:LoadFromFile(def.Path)
		elseif def.Type == "table" then
			entry = SubstanceModules:Register(def.Module)
		end
		if entry then
			SubstanceModules:BuildTab(entry, Window, SubstanceUI)
		end
	end
end

-- settings tab
local settings = Window:CreateTab({ Name = "Settings", Icon = "rbxassetid://7734053495" })

settings:CreateSection({ Name = "Hub" })
settings:CreateToggle({ Name = "Show Notifications", Default = true, Callback = function(v) end })

settings:CreateSeparator()
settings:CreateSection({ Name = "Info" })
settings:CreateLabel({ Text = "Substance Hub v1.0" })
settings:CreateLabel({ Text = "Modules loaded: " .. #SubstanceModules.Loaded })

settings:CreateButton({
	Name = "Destroy Hub",
	Callback = function()
		SubstanceModules:UnloadAll()
		Window:Destroy()
	end,
})
