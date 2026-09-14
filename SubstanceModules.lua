-- module system
-- substance

local SubstanceModules = {}
SubstanceModules.__index = SubstanceModules
SubstanceModules.Loaded = {}
SubstanceModules.BackgroundTasks = {}

function SubstanceModules:Register(mod)
	if not mod or not mod.Name then return nil end

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
	local ok, src = pcall(function()
		return readfile(path)
	end)
	if not ok or not src or src == "" then return nil end

	local loader, err = loadstring(src)
	if not loader then return nil end

	local success, mod = pcall(loader)
	if not success then return nil end

	return self:Register(mod)
end

function SubstanceModules:BuildTab(entry, Window, Fluent)
	local mod = entry.Module

	local tab = Window:AddTab({
		Title = mod.Name or "Module",
		Icon = mod.Icon or "box",
	})
	entry.Tab = tab

	local moduleApi = {
		Running = true,
		Notify = function(cfg)
			if Fluent and Fluent.Notify then
				Fluent:Notify({
					Title = cfg.Title or "Substance",
					Content = cfg.Description or cfg.Content or cfg.Text or "",
					Duration = cfg.Duration or 3,
				})
			end
		end,
		GetPlayers = function() return game:GetService("Players"):GetPlayers() end,
		GetLocalPlayer = function() return game:GetService("Players").LocalPlayer end,
		Tab = tab,
		Window = Window,
		Fluent = Fluent,
	}
	entry.Api = moduleApi

	if mod.Elements then
		for _, el in ipairs(mod.Elements) do
			local id = el.Id or (el.Name and el.Name:gsub("%s+", "") .. tostring(math.random(100, 999))) or ("Item" .. tostring(math.random(100, 999)))

			if el.Type == "Section" then
				tab:AddSection(el.Name)
			elseif el.Type == "Toggle" then
				local t = tab:AddToggle(id, {
					Title = el.Name,
					Description = el.Description or "",
					Default = el.Default or false,
					Callback = el.Callback or function() end,
				})
				el._ref = t
			elseif el.Type == "Dropdown" then
				local d = tab:AddDropdown(id, {
					Title = el.Name,
					Description = el.Description or "",
					Values = el.Values or el.Options or {},
					Multi = el.Multi or false,
					Default = el.Default,
					Callback = el.Callback or function() end,
				})
				el._ref = d
			elseif el.Type == "Slider" then
				local s = tab:AddSlider(id, {
					Title = el.Name,
					Description = el.Description or "",
					Min = el.Min or 0,
					Max = el.Max or 100,
					Default = el.Default or el.Min or 0,
					Rounding = el.Rounding or 1,
					Callback = el.Callback or function() end,
				})
				el._ref = s
			elseif el.Type == "Button" then
				local b = tab:AddButton({
					Title = el.Name,
					Description = el.Description or "",
					Callback = el.Callback or function() end,
				})
				el._ref = b
			elseif el.Type == "Paragraph" or el.Type == "Label" then
				tab:AddParagraph({
					Title = el.Name or el.Title or "Info",
					Content = el.Content or el.Text or "",
				})
			elseif el.Type == "Input" or el.Type == "Textbox" then
				tab:AddInput(id, {
					Title = el.Name,
					Default = el.Default or "",
					Placeholder = el.Placeholder or "",
					Numeric = el.Numeric or false,
					Finished = el.Finished or false,
					Callback = el.Callback or function() end,
				})
			end
		end
	end

	if mod.Init then
		task.spawn(function()
			pcall(mod.Init, moduleApi)
		end)
	end

	if mod.BackgroundTask then
		local t = task.spawn(function()
			pcall(mod.BackgroundTask, moduleApi)
		end)
		table.insert(self.BackgroundTasks, { Thread = t, Api = moduleApi, Module = mod })
	end

	return tab
end

function SubstanceModules:UnloadAll()
	for _, bg in ipairs(self.BackgroundTasks) do
		if bg.Api then bg.Api.Running = false end
	end
	for _, entry in ipairs(self.Loaded) do
		if entry.Api then entry.Api.Running = false end
		if entry.Module.Cleanup then
			pcall(entry.Module.Cleanup)
		end
		entry.Running = false
	end
	self.Loaded = {}
	self.BackgroundTasks = {}
end

return SubstanceModules
