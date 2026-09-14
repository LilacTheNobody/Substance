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

-- key system (memory only)
local VALID_KEY = "releasehellyeah"

if not _G.SubstanceKeyValid then
	local plr = game:GetService("Players").LocalPlayer
	local pg = plr:WaitForChild("PlayerGui")

	local sg = Instance.new("ScreenGui")
	sg.Name = "SubstanceKeyGui"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = pg

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(8, 6, 14)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(360, 210)
	card.Position = UDim2.new(0.5, -180, 0.5, -105)
	card.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
	card.BorderSizePixel = 0
	card.Parent = sg

	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Color3.fromRGB(138, 43, 226)
	stroke.Thickness = 1.5

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.fromOffset(0, 16)
	title.BackgroundTransparency = 1
	title.Text = "Substance"
	title.TextColor3 = Color3.fromRGB(210, 150, 255)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 20)
	subtitle.Position = UDim2.fromOffset(0, 52)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Enter key to continue"
	subtitle.TextColor3 = Color3.fromRGB(150, 130, 180)
	subtitle.TextSize = 13
	subtitle.Font = Enum.Font.Gotham
	subtitle.Parent = card

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(0.82, 0, 0, 36)
	input.Position = UDim2.new(0.09, 0, 0, 88)
	input.BackgroundColor3 = Color3.fromRGB(28, 22, 44)
	input.BorderSizePixel = 0
	input.Text = ""
	input.PlaceholderText = "paste key here..."
	input.PlaceholderColor3 = Color3.fromRGB(100, 85, 130)
	input.TextColor3 = Color3.fromRGB(240, 230, 255)
	input.TextSize = 14
	input.Font = Enum.Font.Gotham
	input.ClearTextOnFocus = false
	input.Parent = card
	Instance.new("UICorner", input).CornerRadius = UDim.new(0, 8)
	local istroke = Instance.new("UIStroke", input)
	istroke.Color = Color3.fromRGB(65, 50, 95)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.82, 0, 0, 36)
	btn.Position = UDim2.new(0.09, 0, 0, 136)
	btn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
	btn.BorderSizePixel = 0
	btn.Text = "Submit"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.Parent = card
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, 0, 0, 20)
	status.Position = UDim2.fromOffset(0, 180)
	status.BackgroundTransparency = 1
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(255, 80, 80)
	status.TextSize = 12
	status.Font = Enum.Font.Gotham
	status.Parent = card

	local keyAccepted = false

	btn.MouseButton1Click:Connect(function()
		local val = input.Text:gsub("%s+", "")
		if val == VALID_KEY then
			keyAccepted = true
			_G.SubstanceKeyValid = true
			status.TextColor3 = Color3.fromRGB(80, 230, 120)
			status.Text = "Key accepted"
			task.wait(0.4)
			sg:Destroy()
		else
			status.TextColor3 = Color3.fromRGB(255, 80, 80)
			status.Text = "Invalid key"
			input.Text = ""
		end
	end)

	repeat task.wait(0.1) until keyAccepted
end

-- loader helpers
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

-- load fluent ui
local Fluent = fetchScript(
	"https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
	"SubstanceUI.lua"
)

if not Fluent then
	Fluent = fetchScript(
		"https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceUI.lua",
		"SubstanceUI.lua"
	)
end

if not Fluent then
	error("[Substance] Failed to load Fluent UI library")
end

-- load module system
local SubstanceModules = fetchScript(
	"https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceModules.lua",
	"SubstanceModules.lua"
)

-- game detection
local mps = game:GetService("MarketplaceService")
local plrs = game:GetService("Players")
local lp = plrs.LocalPlayer
local gameId = game.PlaceId
local gameName = "Unknown Game"

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

-- create acrylic glass window
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

-- home tab
local homeTab = Window:AddTab({ Title = "Home", Icon = "home" })

homeTab:AddSection("Session")
homeTab:AddParagraph({
	Title = "Welcome",
	Content = "User: " .. (lp and lp.Name or "Player") .. "\nGame: " .. gameName .. "\nPlace ID: " .. tostring(gameId),
})

homeTab:AddSection("Actions")
homeTab:AddButton({
	Title = "Rejoin Server",
	Description = "Reconnects to this server",
	Callback = function()
		pcall(function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(gameId, game.JobId, lp)
		end)
	end,
})

homeTab:AddButton({
	Title = "Server Hop",
	Description = "Finds another server",
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
		pcall(function()
			setclipboard(tostring(gameId))
		end)
		Fluent:Notify({
			Title = "Copied",
			Content = "Place ID copied to clipboard",
			Duration = 2,
		})
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
		pcall(function()
			if lp.Character and lp.Character:FindFirstChild("Humanoid") then
				lp.Character.Humanoid.WalkSpeed = v
			end
		end)
	end,
})

playerTab:AddSlider("JumpPower", {
	Title = "JumpPower",
	Min = 50,
	Max = 300,
	Default = 50,
	Rounding = 1,
	Callback = function(v)
		pcall(function()
			if lp.Character and lp.Character:FindFirstChild("Humanoid") then
				lp.Character.Humanoid.JumpPower = v
			end
		end)
	end,
})

local infJumpActive = false
local infJumpConn = nil
playerTab:AddToggle("InfiniteJump", {
	Title = "Infinite Jump",
	Default = false,
	Callback = function(v)
		infJumpActive = v
		if v and not infJumpConn then
			infJumpConn = game:GetService("UserInputService").JumpRequest:Connect(function()
				if infJumpActive and lp.Character and lp.Character:FindFirstChild("Humanoid") then
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

local noclipActive = false
local noclipConn = nil
playerTab:AddToggle("Noclip", {
	Title = "Noclip",
	Default = false,
	Callback = function(v)
		noclipActive = v
		if v and not noclipConn then
			noclipConn = game:GetService("RunService").Stepped:Connect(function()
				if noclipActive and lp.Character then
					pcall(function()
						for _, part in ipairs(lp.Character:GetDescendants()) do
							if part:IsA("BasePart") then
								part.CanCollide = false
							end
						end
					end)
				end
			end)
		elseif not v and noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
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

-- settings tab
local settingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })

settingsTab:AddSection("Theme")
settingsTab:AddDropdown("ThemeSelect", {
	Title = "Color Theme",
	Values = { "Amethyst", "Dark", "Rose", "Aqua", "Light" },
	Default = "Amethyst",
	Callback = function(v)
		if Fluent.SetTheme then
			Fluent:SetTheme(v)
		end
	end,
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

settingsTab:AddSection("Management")
settingsTab:AddParagraph({
	Title = "Controls",
	Content = "Press Left Control to minimize or restore the menu",
})

settingsTab:AddButton({
	Title = "Unload Hub",
	Description = "Closes Substance and cleans up connections",
	Callback = function()
		if SubstanceModules then
			SubstanceModules:UnloadAll()
		end
		if infJumpConn then infJumpConn:Disconnect() end
		if noclipConn then noclipConn:Disconnect() end
		Window:Destroy()
	end,
})

Window:SelectTab(1)
