-- tsb module
-- substance - the strongest battlegrounds
-- elite combat, stealth, visuals & utility suite

local module = {}

local plrs = game:GetService("Players")
local rs = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local vu = game:GetService("VirtualUser")
local vim = nil
pcall(function()
	vim = game:GetService("VirtualInputManager")
end)

local lp = plrs.LocalPlayer
local camera = workspace.CurrentCamera

-- notification helper
local cachedApi = nil
local function apiNotify(cfg)
	if cachedApi and cachedApi.Notify then
		pcall(cachedApi.Notify, cfg)
	end
end

-- configuration
local cfg = {
	-- combat
	autoBlock = false,
	blockRange = 18,
	autoDodge = false,
	autoCounter = false,
	killAura = false,
	auraRange = 14,
	m1Delay = 0.28,
	autoFinisher = "None", -- "None", "Uppercut", "Downslam"
	hitboxExpander = false,
	hitboxSize = 12,
	hitboxTrans = 0.65,
	camlock = false,
	camlockSmoothness = 0.6,
	autoAwaken = false,
	antiRagdoll = false,

	-- stealth & invisibility
	invisible = false,
	invisOpacity = 0.5,

	-- movement & tech
	noSlowdown = false,
	baseSpeed = 16,
	boostedDash = false,
	dashPower = 80,
	antiVoid = true,
	autoGrabTrash = false,

	-- visuals (esp)
	esp = false,
	showNames = true,
	showMoveset = true,
	showHealth = true,
	showDist = true,
	highlightAwakened = true,
	debrisEsp = false,
	tracers = false,
}

-- theme colors (substance amethyst glass palette)
local colors = {
	NormalEnemy = Color3.fromRGB(160, 60, 255),
	Awakened = Color3.fromRGB(255, 215, 0),
	Targeted = Color3.fromRGB(255, 45, 85),
	Debris = Color3.fromRGB(0, 230, 255),
	Tracer = Color3.fromRGB(180, 100, 255),
	Ghost = Color3.fromRGB(175, 120, 255),
	HealthGreen = Color3.fromRGB(50, 225, 90),
	HealthYellow = Color3.fromRGB(255, 205, 40),
	HealthRed = Color3.fromRGB(255, 45, 45),
}

-- moveset & character database
local characterMovesets = {
	["The Strongest Hero (Saitama)"] = {
		Keywords = { "normal punch", "consecutive normal", "shove", "uppercut", "serious punch", "omnidirectional", "table flip", "serious headbutt" },
		AwakenedMoves = { "serious punch", "omnidirectional", "table flip", "serious headbutt" },
	},
	["The Hero Hunter (Garou)"] = {
		Keywords = { "flowing water", "lethal whirlwind", "hunter's grasp", "prey's peril", "final hunt" },
		AwakenedMoves = { "final hunt" },
	},
	["Destructive Cyborg (Genos)"] = {
		Keywords = { "machine gun", "ignition burst", "blitz shot", "jet dive", "incinerate", "maximum output" },
		AwakenedMoves = { "incinerate", "maximum output" },
	},
	["Speed o' Sound Sonic"] = {
		Keywords = { "flash strike", "scatter", "whirlwind kick", "explosive shuriken", "carnage", "twin blades" },
		AwakenedMoves = { "carnage", "twin blades" },
	},
	["Brutal Demon (Metal Bat)"] = {
		Keywords = { "grand slam", "foul ball", "home run", "beatdown", "death blow", "brutal beatdown" },
		AwakenedMoves = { "death blow", "brutal beatdown" },
	},
	["Blade Master (Atomic Samurai)"] = {
		Keywords = { "quick slice", "atmos cleave", "pinpoint cut", "split second counter", "atomic slash", "dual cleave" },
		AwakenedMoves = { "atomic slash", "dual cleave" },
	},
	["Wild Psychic (Tatsumaki)"] = {
		Keywords = { "crushing pull", "telekinetic toss", "stone coffin", "collapsing horizon", "crushing mass" },
		AwakenedMoves = { "collapsing horizon", "crushing mass" },
	},
	["Sorcerer (Gojo / Sukuna)"] = {
		Keywords = { "dismantle", "cleave", "flame arrow", "malevolent shrine", "reversal red", "lapse blue", "hollow purple" },
		AwakenedMoves = { "malevolent shrine", "hollow purple" },
	},
}

-- unblockable / guardbreak moves
local unblockableKeywords = {
	"shove", "uppercut", "serious punch", "table flip", "serious headbutt",
	"hunter's grasp", "ignition burst", "blitz shot", "foul ball", "beatdown",
	"grand slam", "pinpoint cut", "atomic slash", "crushing pull", "stone coffin", "cleave"
}

-- attack keywords for smart block
local attackKeywords = {
	"punch", "m1", "swing", "slash", "kick", "attack", "strike", "hit", "shove",
	"burst", "blow", "slice", "slam", "cleave", "rush", "combo"
}

-- internal state caches
local cachedCharacterData = {}
local highlights = {}
local billboards = {}
local debrisHighlights = {}
local debrisBillboards = {}
local originalHitboxSizes = {}
local conns = {}

local isHoldingBlock = false
local lastM1Click = 0
local m1ComboCounter = 0
local lastDodgeTick = 0
local lastCounterTick = 0
local lastAwakenCheck = 0
local lastVoidCheck = 0
local currentCamlockTarget = nil

-- invisibility state
local invisGhostClone = nil
local storedRootJoint = nil
local storedRootJointC0 = nil
local storedRootJointC1 = nil

-- keyboard & mouse input simulation helpers
local function pressKey(keyCode, isDown)
	pcall(function()
		if vim then
			vim:SendKeyEvent(isDown, keyCode, false, game)
		elseif keypress and keyrelease then
			if isDown then keypress(keyCode.Value) else keyrelease(keyCode.Value) end
		end
	end)
end

local function triggerM1Click()
	pcall(function()
		if vim then
			vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.04)
			vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		elseif mouse1click then
			mouse1click()
		elseif vu then
			vu:CaptureController()
			vu:ClickButton1(Vector2.zero)
		end
	end)
end

-- scan player character & backpack for moveset identification
local function detectPlayerMoveset(p)
	if not p or not p.Parent then return "Unknown", false end

	local toolNames = {}
	local ch = p.Character
	if ch then
		for _, item in ipairs(ch:GetChildren()) do
			if item:IsA("Tool") or item:IsA("Folder") or item:IsA("StringValue") then
				table.insert(toolNames, item.Name:lower())
			end
		end
	end

	local bp = p:FindFirstChild("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") then
				table.insert(toolNames, item.Name:lower())
			end
		end
	end

	local detectedName = "Unknown"
	local isAwakened = false

	for movesetName, data in pairs(characterMovesets) do
		local matches = 0
		for _, toolName in ipairs(toolNames) do
			for _, kw in ipairs(data.Keywords) do
				if toolName:find(kw) then
					matches = matches + 1
					break
				end
			end
			for _, awk in ipairs(data.AwakenedMoves) do
				if toolName:find(awk) then
					isAwakened = true
					break
				end
			end
		end
		if matches > 0 then
			detectedName = movesetName
			break
		end
	end

	-- check attributes or visual auras for awakening
	if ch and not isAwakened then
		if ch:GetAttribute("Awakened") == true or ch:FindFirstChild("AwakeningAura") or ch:FindFirstChild("UltimateActive") then
			isAwakened = true
		end
	end

	return detectedName, isAwakened
end

local function getPlayerData(p)
	if not p then return "Unknown", false end
	local now = tick()
	local cached = cachedCharacterData[p]
	if cached and (now - cached.LastChecked < 3) then
		return cached.Name, cached.Awakened
	end

	local name, awakened = detectPlayerMoveset(p)
	cachedCharacterData[p] = {
		Name = name,
		Awakened = awakened,
		LastChecked = now,
	}
	return name, awakened
end

-- check if an enemy is performing an attack animation
local function checkEnemyAttack(p)
	if not p or p == lp or not p.Character then return false, false, "" end
	local ch = p.Character
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false, false, "" end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return false, false, "" end

	local tracks = {}
	local ok, res = pcall(function() return animator:GetPlayingAnimationTracks() end)
	if ok and res then tracks = res end

	for _, track in ipairs(tracks) do
		if track.IsPlaying and track.WeightCurrent > 0.1 then
			local animName = (track.Name or ""):lower()
			local animId = (track.Animation and track.Animation.AnimationId or ""):lower()

			local isUnblockable = false
			for _, ub in ipairs(unblockableKeywords) do
				if animName:find(ub) or animId:find(ub) then
					isUnblockable = true
					return true, true, animName
				end
			end

			for _, atk in ipairs(attackKeywords) do
				if animName:find(atk) or animId:find(atk) then
					return true, isUnblockable, animName
				end
			end
		end
	end

	return false, false, ""
end

-- find closest enemy
local function getClosestEnemy(maxDist)
	maxDist = maxDist or math.huge
	local myChar = lp.Character
	if not myChar then return nil, maxDist end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil, maxDist end

	local closest = nil
	local closestDist = maxDist

	for _, p in ipairs(plrs:GetPlayers()) do
		if p ~= lp and p.Character then
			local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
			local tHum = p.Character:FindFirstChildOfClass("Humanoid")
			if tRoot and tHum and tHum.Health > 0 then
				local dist = (myRoot.Position - tRoot.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closest = p
				end
			end
		end
	end

	return closest, closestDist
end

-- stealth: fe invisibility with local ghost view
local function setInvisibility(enable)
	cfg.invisible = enable
	local ch = lp.Character
	if not ch then return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	if enable then
		-- locate root joint (R15 LowerTorso.Root, R6 HumanoidRootPart.RootJoint)
		local rJoint = (ch:FindFirstChild("LowerTorso") and ch.LowerTorso:FindFirstChild("Root"))
			or (ch:FindFirstChild("LowerTorso") and ch.LowerTorso:FindFirstChild("RootJoint"))
			or hrp:FindFirstChild("RootJoint")

		if rJoint and rJoint:IsA("Motor6D") then
			storedRootJoint = rJoint
			storedRootJointC0 = rJoint.C0
			storedRootJointC1 = rJoint.C1

			-- destroy previous ghost if any
			if invisGhostClone then
				pcall(function() invisGhostClone:Destroy() end)
				invisGhostClone = nil
			end

			-- create local ghost visual clone
			ch.Archivable = true
			local ghost = ch:Clone()
			ghost.Name = "Substance_GhostVisual"

			-- sanitize ghost clone
			for _, obj in ipairs(ghost:GetDescendants()) do
				if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("Sound") or obj:IsA("BillboardGui") or obj:IsA("Highlight") then
					obj:Destroy()
				elseif obj:IsA("BasePart") then
					obj.CanCollide = false
					obj.Anchored = false
					obj.CastShadow = false
					obj.Transparency = cfg.invisOpacity
					obj.Material = Enum.Material.ForceField
					obj.Color = colors.Ghost
				elseif obj:IsA("Decal") then
					obj.Transparency = cfg.invisOpacity
				end
			end

			local gHrp = ghost:FindFirstChild("HumanoidRootPart")
			if gHrp then
				gHrp.Transparency = 1
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrp
				weld.Part1 = gHrp
				weld.Parent = gHrp
			end

			ghost.Parent = workspace.CurrentCamera
			invisGhostClone = ghost

			-- offset real visual body out of server replication bounds
			rJoint.C0 = CFrame.new(0, 999999, 0)
			apiNotify({
				Title = "Invisibility",
				Content = "FE Invisibility enabled!\nOthers see you invisible; ghost is visible to you.",
				Duration = 4,
			})
		else
			apiNotify({
				Title = "Invisibility",
				Content = "Unable to locate character RootJoint. Reset character and retry.",
				Duration = 3.5,
			})
		end
	else
		-- restore
		if storedRootJoint and storedRootJoint.Parent and storedRootJointC0 then
			pcall(function() storedRootJoint.C0 = storedRootJointC0 end)
		end
		storedRootJoint = nil
		storedRootJointC0 = nil
		storedRootJointC1 = nil

		if invisGhostClone then
			pcall(function() invisGhostClone:Destroy() end)
			invisGhostClone = nil
		end

		apiNotify({ Title = "Invisibility", Content = "Invisibility disabled.", Duration = 2 })
	end
end

-- update ghost transparency dynamically
local function updateGhostOpacity()
	if invisGhostClone then
		for _, obj in ipairs(invisGhostClone:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
				obj.Transparency = cfg.invisOpacity
			elseif obj:IsA("Decal") then
				obj.Transparency = cfg.invisOpacity
			end
		end
	end
end

-- boosted dash impulse
local function triggerBoostedDash()
	if not cfg.boostedDash then return end
	local ch = lp.Character
	if not ch then return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	task.spawn(function()
		local moveDir = ch:FindFirstChildOfClass("Humanoid") and ch.Humanoid.MoveDirection
		local dashDir = (moveDir and moveDir.Magnitude > 0.1) and moveDir or hrp.CFrame.LookVector
		hrp.AssemblyLinearVelocity = dashDir * cfg.dashPower + Vector3.new(0, 8, 0)
	end)
end

-- anti-void fall recovery
local function processAntiVoid()
	if not cfg.antiVoid then return end
	if tick() - lastVoidCheck < 0.4 then return end
	lastVoidCheck = tick()

	local ch = lp.Character
	if not ch then return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if hrp and hrp.Position.Y < -40 then
		pcall(function()
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(hrp.Position.X, 15, hrp.Position.Z)
			apiNotify({ Title = "Anti-Void", Content = "Saved from void drop!", Duration = 2.5 })
		end)
	end
end

-- combat logic: auto block, auto dodge, auto counter
local function processDefense()
	if not (cfg.autoBlock or cfg.autoDodge or cfg.autoCounter) then
		if isHoldingBlock then
			isHoldingBlock = false
			pressKey(Enum.KeyCode.F, false)
		end
		return
	end

	local myChar = lp.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local myHum = myChar:FindFirstChildOfClass("Humanoid")
	if not myRoot or not myHum or myHum.Health <= 0 then
		if isHoldingBlock then
			isHoldingBlock = false
			pressKey(Enum.KeyCode.F, false)
		end
		return
	end

	local shouldBlock = false
	local incomingGuardbreak = false

	for _, p in ipairs(plrs:GetPlayers()) do
		if p ~= lp and p.Character then
			local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
			if tRoot then
				local dist = (myRoot.Position - tRoot.Position).Magnitude
				if dist <= cfg.blockRange then
					local isAttacking, isUnblockable, animName = checkEnemyAttack(p)
					if isAttacking then
						if isUnblockable then
							incomingGuardbreak = true
						else
							shouldBlock = true
						end
					end
				end
			end
		end
	end

	-- auto dodge / dash on guardbreak moves
	if incomingGuardbreak and cfg.autoDodge and (tick() - lastDodgeTick > 1.2) then
		lastDodgeTick = tick()
		pressKey(Enum.KeyCode.Q, true)
		task.delay(0.05, function() pressKey(Enum.KeyCode.Q, false) end)
		if cfg.boostedDash then triggerBoostedDash() end
		apiNotify({ Title = "Auto Dodge", Content = "Dodged incoming guardbreak!", Duration = 1.5 })
	end

	-- auto counter if character possesses a counter move
	if shouldBlock and cfg.autoCounter and (tick() - lastCounterTick > 4.0) then
		local myMoveset = detectPlayerMoveset(lp)
		if myMoveset:find("Garou") or myMoveset:find("Atomic Samurai") then
			lastCounterTick = tick()
			pressKey(Enum.KeyCode.Four, true)
			task.delay(0.05, function() pressKey(Enum.KeyCode.Four, false) end)
		end
	end

	-- auto block holding
	if cfg.autoBlock then
		if shouldBlock and not incomingGuardbreak then
			if not isHoldingBlock then
				isHoldingBlock = true
				pressKey(Enum.KeyCode.F, true)
			end
		else
			if isHoldingBlock then
				isHoldingBlock = false
				pressKey(Enum.KeyCode.F, false)
			end
		end
	end
end

-- kill aura / auto m1 combo with auto finisher
local function processKillAura()
	if not cfg.killAura then return end
	local myChar = lp.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local myHum = myChar:FindFirstChildOfClass("Humanoid")
	if not myRoot or not myHum or myHum.Health <= 0 then return end

	local enemy, dist = getClosestEnemy(cfg.auraRange)
	if not enemy or not enemy.Character then return end
	local enemyRoot = enemy.Character:FindFirstChild("HumanoidRootPart")
	if not enemyRoot then return end

	-- face enemy
	myRoot.CFrame = CFrame.lookAt(myRoot.Position, Vector3.new(enemyRoot.Position.X, myRoot.Position.Y, enemyRoot.Position.Z))

	-- trigger M1 click
	if tick() - lastM1Click >= cfg.m1Delay then
		lastM1Click = tick()
		m1ComboCounter = (m1ComboCounter % 4) + 1

		-- auto finisher tech on 4th hit
		if m1ComboCounter == 4 and cfg.autoFinisher ~= "None" then
			if cfg.autoFinisher == "Uppercut" then
				-- jump before 4th hit for aerial launcher
				pressKey(Enum.KeyCode.Space, true)
				task.delay(0.1, function() pressKey(Enum.KeyCode.Space, false) end)
			elseif cfg.autoFinisher == "Downslam" and camera then
				-- angle camera downward for downslam
				camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-30), 0, 0)
			end
		end

		triggerM1Click()
	end
end

-- hitbox expander
local function applyHitboxExpander()
	for _, p in ipairs(plrs:GetPlayers()) do
		if p ~= lp and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				if cfg.hitboxExpander then
					if not originalHitboxSizes[p] then
						originalHitboxSizes[p] = { Size = hrp.Size, Transparency = hrp.Transparency, CanCollide = hrp.CanCollide }
					end
					hrp.Size = Vector3.new(cfg.hitboxSize, cfg.hitboxSize, cfg.hitboxSize)
					hrp.Transparency = cfg.hitboxTrans
					hrp.CanCollide = false
					hrp.Color = colors.NormalEnemy
					hrp.Material = Enum.Material.ForceField
				else
					if originalHitboxSizes[p] then
						hrp.Size = originalHitboxSizes[p].Size
						hrp.Transparency = originalHitboxSizes[p].Transparency
						hrp.CanCollide = originalHitboxSizes[p].CanCollide
						hrp.Material = Enum.Material.Plastic
						originalHitboxSizes[p] = nil
					end
				end
			end
		end
	end
end

-- anti-ragdoll / instant recovery
local function processAntiRagdoll()
	if not cfg.antiRagdoll then return end
	local myChar = lp.Character
	if not myChar then return end
	local hum = myChar:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	pcall(function()
		for _, desc in ipairs(myChar:GetDescendants()) do
			if desc:IsA("BallSocketConstraint") or desc:IsA("HingeConstraint") then
				if desc.Name:lower():find("ragdoll") or desc.Parent.Name:lower():find("arm") or desc.Parent.Name:lower():find("leg") then
					desc:Destroy()
				end
			elseif desc:IsA("Folder") and desc.Name:lower():find("ragdoll") then
				desc:Destroy()
			end
		end

		if hum.PlatformStand then
			hum.PlatformStand = false
		end
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)
end

-- no attack slowdown
local function processNoSlowdown()
	if not cfg.noSlowdown then return end
	local myChar = lp.Character
	if not myChar then return end
	local hum = myChar:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	if hum.WalkSpeed < cfg.baseSpeed then
		hum.WalkSpeed = cfg.baseSpeed
	end
end

-- auto awakening
local function processAutoAwaken()
	if not cfg.autoAwaken then return end
	if tick() - lastAwakenCheck < 2.0 then return end
	lastAwakenCheck = tick()

	pcall(function()
		local myMoveset, isAwk = detectPlayerMoveset(lp)
		if isAwk then return end

		local pg = lp:FindFirstChild("PlayerGui")
		if not pg then return end

		local isUltReady = false
		for _, gui in ipairs(pg:GetDescendants()) do
			if gui:IsA("Frame") or gui:IsA("ImageLabel") then
				local n = gui.Name:lower()
				if n:find("ult") or n:find("awaken") or n:find("special") then
					if gui.Size.X.Scale >= 0.98 or gui.Size.Y.Scale >= 0.98 then
						isUltReady = true
						break
					end
				end
			end
		end

		if isUltReady then
			pressKey(Enum.KeyCode.G, true)
			task.delay(0.08, function() pressKey(Enum.KeyCode.G, false) end)
			apiNotify({ Title = "Auto Awakening", Content = "Ultimate meter full! Popped Awakening (G).", Duration = 3 })
		end
	end)
end

-- camlock / target lock
local function updateCamlock()
	if not cfg.camlock then
		currentCamlockTarget = nil
		return
	end

	local target, dist = getClosestEnemy(80)
	currentCamlockTarget = target
	if target and target.Character then
		local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
		if tRoot and camera then
			local targetCFrame = CFrame.lookAt(camera.CFrame.Position, tRoot.Position + Vector3.new(0, 1.5, 0))
			camera.CFrame = camera.CFrame:Lerp(targetCFrame, cfg.camlockSmoothness)
		end
	end
end

-- esp cleanup helpers
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
	highlights = {}
	billboards = {}
end

local function clearDebrisESP()
	for _, hl in pairs(debrisHighlights) do pcall(function() hl:Destroy() end) end
	for _, bb in pairs(debrisBillboards) do pcall(function() bb:Destroy() end) end
	debrisHighlights = {}
	debrisBillboards = {}
end

-- create or update player esp
local function updatePlayerESP(p)
	if not cfg.esp or p == lp or not p.Character then
		clearPlayerESP(p)
		return
	end

	local ch = p.Character
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	local hum = ch:FindFirstChildOfClass("Humanoid")

	if not hrp or not hum or hum.Health <= 0 then
		clearPlayerESP(p)
		return
	end

	local movesetName, isAwk = getPlayerData(p)
	local dist = 0
	if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
		dist = math.floor((lp.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
	end

	-- highlight
	local hl = highlights[p]
	if not hl or hl.Parent ~= ch then
		if hl then pcall(function() hl:Destroy() end) end
		hl = Instance.new("Highlight")
		hl.Name = "Substance_TSB_HL"
		hl.Adornee = ch
		hl.FillTransparency = 0.6
		hl.OutlineTransparency = 0.1
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = ch
		highlights[p] = hl
	end

	if isAwk and cfg.highlightAwakened then
		hl.FillColor = colors.Awakened
		hl.OutlineColor = colors.Awakened
	elseif currentCamlockTarget == p then
		hl.FillColor = colors.Targeted
		hl.OutlineColor = colors.Targeted
	else
		hl.FillColor = colors.NormalEnemy
		hl.OutlineColor = colors.NormalEnemy
	end

	-- billboard tag
	local bb = billboards[p]
	if not bb or bb.Parent ~= hrp then
		if bb then pcall(function() bb:Destroy() end) end
		bb = Instance.new("BillboardGui")
		bb.Name = "Substance_TSB_Tag"
		bb.Adornee = hrp
		bb.Size = UDim2.fromOffset(190, 70)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true

		local frame = Instance.new("Frame")
		frame.Name = "TagFrame"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		frame.BackgroundTransparency = 0.35
		frame.BorderSizePixel = 0
		frame.Parent = bb

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Name = "TagStroke"
		stroke.Color = colors.NormalEnemy
		stroke.Thickness = 1.2
		stroke.Parent = frame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.Position = UDim2.new(0, 0, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Parent = frame

		local movesetLabel = Instance.new("TextLabel")
		movesetLabel.Name = "MovesetLabel"
		movesetLabel.Size = UDim2.new(1, 0, 0, 15)
		movesetLabel.Position = UDim2.new(0, 0, 0, 22)
		movesetLabel.BackgroundTransparency = 1
		movesetLabel.Font = Enum.Font.GothamMedium
		movesetLabel.TextSize = 10
		movesetLabel.TextColor3 = colors.Awakened
		movesetLabel.Parent = frame

		local healthBarBg = Instance.new("Frame")
		healthBarBg.Name = "HealthBarBg"
		healthBarBg.Size = UDim2.new(0.88, 0, 0, 6)
		healthBarBg.Position = UDim2.new(0.06, 0, 0, 40)
		healthBarBg.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		healthBarBg.BorderSizePixel = 0
		healthBarBg.Parent = frame

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0, 3)
		barCorner.Parent = healthBarBg

		local healthFill = Instance.new("Frame")
		healthFill.Name = "HealthFill"
		healthFill.Size = UDim2.new(1, 0, 1, 0)
		healthFill.BackgroundColor3 = colors.HealthGreen
		healthFill.BorderSizePixel = 0
		healthFill.Parent = healthBarBg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 3)
		fillCorner.Parent = healthFill

		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "SubLabel"
		subLabel.Size = UDim2.new(1, 0, 0, 14)
		subLabel.Position = UDim2.new(0, 0, 0, 50)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.Gotham
		subLabel.TextSize = 9
		subLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		subLabel.Parent = frame

		bb.Parent = hrp
		billboards[p] = bb
	end

	-- update tag content
	local frame = bb:FindFirstChild("TagFrame")
	if frame then
		local nameLabel = frame:FindFirstChild("NameLabel")
		local movesetLabel = frame:FindFirstChild("MovesetLabel")
		local healthBarBg = frame:FindFirstChild("HealthBarBg")
		local healthFill = healthBarBg and healthBarBg:FindFirstChild("HealthFill")
		local subLabel = frame:FindFirstChild("SubLabel")
		local stroke = frame:FindFirstChild("TagStroke")

		if stroke then
			stroke.Color = (isAwk and colors.Awakened) or (currentCamlockTarget == p and colors.Targeted) or colors.NormalEnemy
		end

		if nameLabel then
			nameLabel.Text = (cfg.showNames and p.DisplayName or "")
		end

		if movesetLabel then
			if cfg.showMoveset then
				movesetLabel.Text = (isAwk and "★ AWAKENED ★ " or "") .. movesetName
				movesetLabel.TextColor3 = isAwk and colors.Awakened or Color3.fromRGB(200, 160, 255)
			else
				movesetLabel.Text = ""
			end
		end

		local hp = math.max(0, math.floor(hum.Health))
		local maxHp = math.max(1, math.floor(hum.MaxHealth))
		local pct = math.clamp(hp / maxHp, 0, 1)

		if healthFill then
			healthFill.Size = UDim2.new(pct, 0, 1, 0)
			if pct > 0.5 then
				healthFill.BackgroundColor3 = colors.HealthGreen
			elseif pct > 0.25 then
				healthFill.BackgroundColor3 = colors.HealthYellow
			else
				healthFill.BackgroundColor3 = colors.HealthRed
			end
		end

		if subLabel then
			local parts = {}
			if cfg.showHealth then table.insert(parts, tostring(hp) .. "/" .. tostring(maxHp) .. " HP") end
			if cfg.showDist then table.insert(parts, tostring(dist) .. "m") end
			subLabel.Text = table.concat(parts, "  •  ")
		end
	end
end

-- debris & throwable prop esp
local function updateDebrisESP()
	if not cfg.debrisEsp then
		clearDebrisESP()
		return
	end

	local debrisNames = { "trash can", "trashcan", "pole", "dumpster", "rock", "debris", "crate", "vending machine" }
	for _, obj in ipairs(workspace:GetChildren()) do
		local n = obj.Name:lower()
		local isDebris = false
		for _, kw in ipairs(debrisNames) do
			if n:find(kw) then
				isDebris = true
				break
			end
		end

		if isDebris and (obj:IsA("BasePart") or obj:IsA("Model")) then
			local rootPart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
			if rootPart and not debrisHighlights[obj] then
				local hl = Instance.new("Highlight")
				hl.Adornee = obj
				hl.FillColor = colors.Debris
				hl.OutlineColor = colors.Debris
				hl.FillTransparency = 0.7
				hl.OutlineTransparency = 0.2
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = obj
				debrisHighlights[obj] = hl

				local bb = Instance.new("BillboardGui")
				bb.Adornee = rootPart
				bb.Size = UDim2.fromOffset(100, 24)
				bb.StudsOffset = Vector3.new(0, 2, 0)
				bb.AlwaysOnTop = true

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamBold
				lbl.TextSize = 10
				lbl.TextColor3 = colors.Debris
				lbl.Text = obj.Name
				lbl.Parent = bb
				bb.Parent = rootPart
				debrisBillboards[obj] = bb
			end
		end
	end
end

-- grab nearest throwable
local function grabNearestThrowable()
	local myChar = lp.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end

	local debrisNames = { "trash can", "trashcan", "pole", "dumpster", "rock", "debris", "crate" }
	local closestObj = nil
	local closestDist = 25

	for _, obj in ipairs(workspace:GetChildren()) do
		local n = obj.Name:lower()
		for _, kw in ipairs(debrisNames) do
			if n:find(kw) and (obj:IsA("BasePart") or obj:IsA("Model")) then
				local pos = obj:GetPivot().Position
				local dist = (myRoot.Position - pos).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestObj = obj
				end
			end
		end
	end

	if closestObj then
		pcall(function()
			pressKey(Enum.KeyCode.E, true)
			task.delay(0.1, function() pressKey(Enum.KeyCode.E, false) end)
			apiNotify({ Title = "Throwable", Content = "Interacted with " .. closestObj.Name, Duration = 2 })
		end)
	else
		apiNotify({ Title = "Throwable", Content = "No throwable items nearby (within 25m).", Duration = 2 })
	end
end

-- fast arena teleport helper
local function teleportTo(cf, label)
	local myChar = lp.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if myRoot then
		myRoot.AssemblyLinearVelocity = Vector3.zero
		myRoot.CFrame = cf
		apiNotify({ Title = "Teleport", Content = "Teleported to " .. label, Duration = 2 })
	end
end

-- module metadata
module.Name = "TSB"
module.GameId = 10449761463
module.GameName = "The Strongest Battlegrounds"
module.Author = "Substance"
module.Version = "1.2"
module.Icon = "swords"

-- ui elements definition
module.Elements = {
	{ Type = "Section", Name = "Stealth & Invisibility" },

	{
		Type = "Toggle",
		Name = "Invisibility (FE Ghost)",
		Description = "Makes you 100% invisible to all other players; you see yourself as a ghost",
		Default = false,
		Callback = function(v)
			setInvisibility(v)
		end,
	},

	{
		Type = "Slider",
		Name = "Ghost Self Opacity",
		Description = "Local transparency of your own character while invisible",
		Min = 0.1,
		Max = 0.9,
		Default = 0.5,
		Rounding = 2,
		Callback = function(v)
			cfg.invisOpacity = v
			updateGhostOpacity()
		end,
	},

	{ Type = "Section", Name = "Combat" },

	{
		Type = "Toggle",
		Name = "Auto Block",
		Description = "Smart block that detects enemy attack animations & releases when safe",
		Default = false,
		Callback = function(v)
			cfg.autoBlock = v
			if not v and isHoldingBlock then
				isHoldingBlock = false
				pressKey(Enum.KeyCode.F, false)
			end
		end,
	},

	{
		Type = "Slider",
		Name = "Block Detection Range",
		Description = "Distance in studs to monitor enemy incoming attacks",
		Min = 8,
		Max = 30,
		Default = 18,
		Rounding = 1,
		Callback = function(v)
			cfg.blockRange = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Dodge / Dash",
		Description = "Automatically dashes (Q) when an unblockable guardbreak move is incoming",
		Default = false,
		Callback = function(v)
			cfg.autoDodge = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Counter",
		Description = "Automatically activates counter move (Garou / Atomic Samurai) on attack",
		Default = false,
		Callback = function(v)
			cfg.autoCounter = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Kill Aura / Auto M1",
		Description = "Automatically faces nearest enemy in range and clicks M1 combo strikes",
		Default = false,
		Callback = function(v)
			cfg.killAura = v
			m1ComboCounter = 0
		end,
	},

	{
		Type = "Slider",
		Name = "Kill Aura Range",
		Description = "Maximum strike distance for auto M1 strikes",
		Min = 6,
		Max = 25,
		Default = 14,
		Rounding = 1,
		Callback = function(v)
			cfg.auraRange = v
		end,
	},

	{
		Type = "Slider",
		Name = "M1 Combo Pacing",
		Description = "Delay between M1 clicks in seconds",
		Min = 0.15,
		Max = 0.5,
		Default = 0.28,
		Rounding = 2,
		Callback = function(v)
			cfg.m1Delay = v
		end,
	},

	{
		Type = "Dropdown",
		Name = "Auto Finisher Tech",
		Description = "Choose special 4th M1 finisher modification",
		Values = { "None", "Uppercut", "Downslam" },
		Default = "None",
		Callback = function(v)
			cfg.autoFinisher = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Hitbox Expander",
		Description = "Expands enemy hitboxes for effortless M1 and ability connects",
		Default = false,
		Callback = function(v)
			cfg.hitboxExpander = v
			applyHitboxExpander()
		end,
	},

	{
		Type = "Slider",
		Name = "Hitbox Size",
		Description = "Stud dimensions for expanded enemy hitboxes",
		Min = 4,
		Max = 35,
		Default = 12,
		Rounding = 1,
		Callback = function(v)
			cfg.hitboxSize = v
			if cfg.hitboxExpander then applyHitboxExpander() end
		end,
	},

	{
		Type = "Slider",
		Name = "Hitbox Transparency",
		Description = "Visibility of expanded hitboxes",
		Min = 0.1,
		Max = 1.0,
		Default = 0.65,
		Rounding = 2,
		Callback = function(v)
			cfg.hitboxTrans = v
			if cfg.hitboxExpander then applyHitboxExpander() end
		end,
	},

	{
		Type = "Toggle",
		Name = "Target Camlock",
		Description = "Smoothly locks camera angle onto nearest opponent",
		Default = false,
		Callback = function(v)
			cfg.camlock = v
			if not v then currentCamlockTarget = nil end
		end,
	},

	{
		Type = "Toggle",
		Name = "Auto Awakening (G)",
		Description = "Automatically triggers ultimate mode when awakening meter hits 100%",
		Default = false,
		Callback = function(v)
			cfg.autoAwaken = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Anti-Ragdoll / Quick Recover",
		Description = "Disables ragdoll physics constraints and forces instant stand-up",
		Default = false,
		Callback = function(v)
			cfg.antiRagdoll = v
		end,
	},

	{ Type = "Section", Name = "Visuals (ESP)" },

	{
		Type = "Toggle",
		Name = "Enable ESP",
		Description = "Master toggle for character ESP overlays and outlines",
		Default = false,
		Callback = function(v)
			cfg.esp = v
			if not v then clearAllESP() end
		end,
	},

	{
		Type = "Toggle",
		Name = "Show Moveset / Character",
		Description = "Identifies Saitama, Garou, Genos, Sonic, Metal Bat, Atomic, Tatsumaki",
		Default = true,
		Callback = function(v)
			cfg.showMoveset = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Show Health Bar",
		Description = "Displays HP percentage bar and exact health values",
		Default = true,
		Callback = function(v)
			cfg.showHealth = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Show Distance",
		Description = "Displays distance in meters to target",
		Default = true,
		Callback = function(v)
			cfg.showDist = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Highlight Awakened Users",
		Description = "Changes highlight and tag stroke to bright gold for awakened enemies",
		Default = true,
		Callback = function(v)
			cfg.highlightAwakened = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Debris & Throwable ESP",
		Description = "Highlights trash cans, rocks, poles and crates with distance markers",
		Default = false,
		Callback = function(v)
			cfg.debrisEsp = v
			if not v then clearDebrisESP() end
		end,
	},

	{ Type = "Section", Name = "Movement & Tech" },

	{
		Type = "Toggle",
		Name = "Boosted Dash (Q)",
		Description = "Gives instant forward velocity impulse upon dashing",
		Default = false,
		Callback = function(v)
			cfg.boostedDash = v
		end,
	},

	{
		Type = "Slider",
		Name = "Dash Impulse Power",
		Description = "Velocity power added to Q dash",
		Min = 40,
		Max = 120,
		Default = 80,
		Rounding = 1,
		Callback = function(v)
			cfg.dashPower = v
		end,
	},

	{
		Type = "Toggle",
		Name = "Anti-Void Fall Rescue",
		Description = "Automatically teleports you back up if knocked below map boundaries",
		Default = true,
		Callback = function(v)
			cfg.antiVoid = v
		end,
	},

	{
		Type = "Toggle",
		Name = "No Attack Slowdown",
		Description = "Prevents game from slowing WalkSpeed during punches and charge moves",
		Default = false,
		Callback = function(v)
			cfg.noSlowdown = v
		end,
	},

	{
		Type = "Slider",
		Name = "Combat WalkSpeed",
		Description = "Movement speed maintained during combat animations",
		Min = 16,
		Max = 80,
		Default = 16,
		Rounding = 1,
		Callback = function(v)
			cfg.baseSpeed = v
		end,
	},

	{
		Type = "Button",
		Name = "Grab Nearest Throwable",
		Description = "Pulls and equips the closest trash can or pole into your hands",
		Callback = function()
			grabNearestThrowable()
		end,
	},

	{
		Type = "Button",
		Name = "Instant Respawn",
		Description = "Instantly resets character to get back into the arena without delay",
		Callback = function()
			if lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") then
				lp.Character.Humanoid.Health = 0
				apiNotify({ Title = "Respawn", Content = "Respawning character...", Duration = 2 })
			end
		end,
	},

	{ Type = "Section", Name = "Arena Teleports" },

	{
		Type = "Button",
		Name = "Teleport: Main Arena",
		Description = "Teleports to the center of the battlefield",
		Callback = function()
			teleportTo(CFrame.new(0, 15, 0), "Main Arena")
		end,
	},

	{
		Type = "Button",
		Name = "Teleport: Mountain Peak",
		Description = "Teleports to the high mountain cliff overlook",
		Callback = function()
			teleportTo(CFrame.new(200, 140, -180), "Mountain Peak")
		end,
	},

	{
		Type = "Button",
		Name = "Teleport: Colosseum",
		Description = "Teleports to the side colosseum courtyard",
		Callback = function()
			teleportTo(CFrame.new(150, 20, 120), "Colosseum")
		end,
	},

	{
		Type = "Button",
		Name = "Teleport: Safe Rooftop Vantage",
		Description = "Teleports to high safe rooftop to regenerate HP",
		Callback = function()
			teleportTo(CFrame.new(-120, 85, 150), "Safe Rooftop Vantage")
		end,
	},

	{ Type = "Section", Name = "Utilities" },

	{
		Type = "Button",
		Name = "Dump Server Movesets",
		Description = "Scans all players in the server and prints moveset analysis to console",
		Callback = function()
			local lines = { "=== TSB Server Moveset Report ===" }
			for _, p in ipairs(plrs:GetPlayers()) do
				local name, awk = detectPlayerMoveset(p)
				table.insert(lines, string.format("[%s (%s)] -> %s%s", p.DisplayName, p.Name, name, awk and " [AWAKENED]" or ""))
			end
			table.insert(lines, "=================================")
			print(table.concat(lines, "\n"))
			apiNotify({ Title = "Moveset Dump", Content = "Moveset dump printed to F9 Developer Console!", Duration = 4 })
		end,
	},
}

-- module initialization hook
module.Init = function(api)
	cachedApi = api
	apiNotify({
		Title = "Substance TSB",
		Content = "The Strongest Battlegrounds suite loaded!",
		Duration = 4,
	})

	-- player leave cleanup
	local leaveConn = plrs.PlayerRemoving:Connect(function(p)
		clearPlayerESP(p)
		cachedCharacterData[p] = nil
		originalHitboxSizes[p] = nil
	end)
	table.insert(conns, leaveConn)

	-- character respawn handler
	local charConn = lp.CharacterAdded:Connect(function(newChar)
		task.wait(0.5)
		if cfg.invisible then
			setInvisibility(true)
		end
		if cfg.hitboxExpander then
			applyHitboxExpander()
		end
	end)
	table.insert(conns, charConn)

	-- user input for boosted dash
	local inputConn = uis.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Q and cfg.boostedDash then
			triggerBoostedDash()
		end
	end)
	table.insert(conns, inputConn)

	-- renderstep hook for camlock
	local camConn = rs.RenderStepped:Connect(function()
		if cfg.camlock then
			pcall(updateCamlock)
		end
	end)
	table.insert(conns, camConn)
end

-- background update loop
module.BackgroundTask = function(api)
	while api.Running do
		pcall(function()
			-- defense routine
			processDefense()

			-- combat routine
			processKillAura()

			-- tech routines
			processAntiRagdoll()
			processNoSlowdown()
			processAutoAwaken()
			processAntiVoid()

			-- visuals routine
			if cfg.esp then
				for _, p in ipairs(plrs:GetPlayers()) do
					if p ~= lp then
						updatePlayerESP(p)
					end
				end
			end

			-- debris routine
			if cfg.debrisEsp then
				updateDebrisESP()
			end
		end)

		task.wait(0.08)
	end
end

-- cleanup routine
module.Cleanup = function()
	clearAllESP()
	clearDebrisESP()

	cfg.hitboxExpander = false
	applyHitboxExpander()

	if cfg.invisible then
		setInvisibility(false)
	end

	if isHoldingBlock then
		isHoldingBlock = false
		pressKey(Enum.KeyCode.F, false)
	end

	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	conns = {}

	cachedCharacterData = {}
	currentCamlockTarget = nil
end

return module
