-- Substance Loader

local src = ""
pcall(function()
	src = game:HttpGet("https://raw.githubusercontent.com/LilacTheNobody/Substance/main/SubstanceHub.lua", true)
end)

if src == "" then
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "Substance",
		Text = "Failed to load. Check connection.",
		Duration = 5,
	})
	return
end

loadstring(src)()
