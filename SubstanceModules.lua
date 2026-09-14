-- Substance Module System
-- handles loading and building tabs from game modules

local SubstanceModules = {}
SubstanceModules.__index = SubstanceModules
SubstanceModules.Loaded = {}
SubstanceModules.BackgroundTasks = {}

function SubstanceModules:Register(mod)
	if not mod or not mod.Name then return end

	local entry = {
		Module = mod,
		Running = true,
		Connections = {},
		Tab = nil,
	}

	table.insert(self.Loaded, entry)
	return entry
end

function SubstanceModules:LoadFromURL(url)
	local ok, src = pcall(function()
		return game:HttpGet(url, true)
	end)
	if not ok or not src or src == "" then return nil end

	local loader, err = loadstring(src)
	if not loader then return nil end

	local success, mod = pcall(loader)
	if not success then return nil end

	return self:Register(mod)
end

function SubstanceModules:LoadFromFile(path)
	local ok, src = pcall(function() return readfile(path) end)
	if not ok or not src then return nil end

	local loader, err = loadstring(src)
	if not loader then return nil end

	local success, mod = pcall(loader)
	if not success then return nil end

	return self:Register(mod)
end

-- takes a module entry + window and builds a tab with all the elements
function SubstanceModules:BuildTab(entry, Window, SubstanceUI)
	local mod = entry.Module

	local tab = Window:CreateTab({
		Name = mod.Name or "Module",
		Icon = mod.Icon,
	})
	entry.Tab = tab

	local moduleApi = {
		Running = true,
		Notify = function(config) SubstanceUI:Notify(config) end,
		GetPlayers = function() return game:GetService("Players"):GetPlayers() end,
		GetLocalPlayer = function() return game:GetService("Players").LocalPlayer end,
		Tab = tab,
		Window = Window,
	}
	entry.Api = moduleApi

	if mod.Elements then
		for _, el in ipairs(mod.Elements) do
			if el.Type == "Section" then
				tab:CreateSection({ Name = el.Name })
			elseif el.Type == "Button" then
				tab:CreateButton({ Name = el.Name, Callback = el.Callback })
			elseif el.Type == "Toggle" then
				el._ref = tab:CreateToggle({ Name = el.Name, Default = el.Default, Callback = el.Callback })
			elseif el.Type == "Slider" then
				el._ref = tab:CreateSlider({ Name = el.Name, Min = el.Min, Max = el.Max, Default = el.Default, Callback = el.Callback })
			elseif el.Type == "Label" then
				el._ref = tab:CreateLabel({ Text = el.Text })
			elseif el.Type == "Textbox" then
				tab:CreateTextbox({ Name = el.Name, Placeholder = el.Placeholder, Default = el.Default, Callback = el.Callback })
			elseif el.Type == "Dropdown" then
				el._ref = tab:CreateDropdown({ Name = el.Name, Options = el.Options, Default = el.Default, Callback = el.Callback })
			elseif el.Type == "Separator" then
				tab:CreateSeparator()
			end
		end
	end

	if mod.Init then
		task.spawn(function() pcall(mod.Init, moduleApi) end)
	end

	if mod.BackgroundTask then
		local t = task.spawn(function() pcall(mod.BackgroundTask, moduleApi) end)
		table.insert(self.BackgroundTasks, { Thread = t, Api = moduleApi, Module = mod })
	end

	return tab
end

function SubstanceModules:GetForGame(placeId)
	local result = {}
	for _, entry in ipairs(self.Loaded) do
		if entry.Module.GameId == nil or entry.Module.GameId == placeId then
			table.insert(result, entry)
		end
	end
	return result
end

function SubstanceModules:UnloadAll()
	for _, bg in ipairs(self.BackgroundTasks) do bg.Api.Running = false end
	for _, entry in ipairs(self.Loaded) do
		if entry.Module.Cleanup then pcall(entry.Module.Cleanup) end
		entry.Running = false
	end
	self.Loaded = {}
	self.BackgroundTasks = {}
end

function SubstanceModules:Unload(name)
	for i, entry in ipairs(self.Loaded) do
		if entry.Module.Name == name then
			if entry.Api then entry.Api.Running = false end
			if entry.Module.Cleanup then pcall(entry.Module.Cleanup) end
			table.remove(self.Loaded, i)
			return true
		end
	end
	return false
end

return SubstanceModules
