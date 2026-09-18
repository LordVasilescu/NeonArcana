--!nonstrict
-- CombatUI: card hand, health bars, cycle counter, round timer. All built in code
-- so Rojo owns everything — no hand-made GUI instances to lose track of.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpellData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpellData"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRequest = remotes:WaitForChild("CastRequest")
local battleState = remotes:WaitForChild("BattleState")
local battleEnd = remotes:WaitForChild("BattleEnd")

local player = Players.LocalPlayer

local SCHOOL_COLORS = {
	Burnout = Color3.fromRGB(255, 100, 40),
	Coolant = Color3.fromRGB(80, 180, 255),
	Surge = Color3.fromRGB(200, 80, 255),
	Patch = Color3.fromRGB(80, 255, 140),
	Leech = Color3.fromRGB(150, 150, 150),
	Ghost = Color3.fromRGB(255, 220, 80),
	Kernel = Color3.fromRGB(230, 180, 130),
}

-- ---------- build static GUI ----------
local gui = Instance.new("ScreenGui")
gui.Name = "CombatUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeBar(anchorX: number)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.3, 0.08)
	frame.Position = UDim2.fromScale(anchorX, 0.06)
	frame.AnchorPoint = Vector2.new(anchorX == 0.05 and 0 or 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(60, 255, 170)
	fill.BorderSizePixel = 0
	fill.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.ZIndex = 2
	label.Parent = frame

	return frame
end

local playerBar = makeBar(0.05)
local enemyBar = makeBar(0.95)
enemyBar.Fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)

local targetFrame = Instance.new("Frame")
targetFrame.Size = UDim2.fromScale(0.3, 0.05)
targetFrame.Position = UDim2.fromScale(0.95, 0.145)
targetFrame.AnchorPoint = Vector2.new(1, 0)
targetFrame.BackgroundTransparency = 1
targetFrame.Parent = gui
local targetLayout = Instance.new("UIListLayout")
targetLayout.FillDirection = Enum.FillDirection.Horizontal
targetLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
targetLayout.Padding = UDim.new(0, 6)
targetLayout.Parent = targetFrame

local selectedTarget = 1

local allyLabel = Instance.new("TextLabel")
allyLabel.Size = UDim2.fromScale(0.3, 0.04)
allyLabel.Position = UDim2.fromScale(0.05, 0.145)
allyLabel.BackgroundTransparency = 1
allyLabel.TextColor3 = Color3.fromRGB(120, 255, 220)
allyLabel.TextScaled = true
allyLabel.Font = Enum.Font.Code
allyLabel.TextXAlignment = Enum.TextXAlignment.Left
allyLabel.Text = ""
allyLabel.Parent = gui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromScale(0.4, 0.07)
statusLabel.Position = UDim2.fromScale(0.5, 0.02)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(120, 255, 220)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Code
statusLabel.Parent = gui

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.fromScale(0.44, 0.16)
logLabel.Position = UDim2.fromScale(0.5, 0.1)
logLabel.AnchorPoint = Vector2.new(0.5, 0)
logLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
logLabel.BackgroundTransparency = 0.35
logLabel.BorderSizePixel = 0
logLabel.TextColor3 = Color3.new(1, 1, 1)
logLabel.TextSize = 16
logLabel.Font = Enum.Font.Code
logLabel.TextWrapped = true
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Visible = false
logLabel.Parent = gui

local hand = Instance.new("Frame")
hand.Size = UDim2.fromScale(0.9, 0.22)
hand.Position = UDim2.fromScale(0.5, 0.97)
hand.AnchorPoint = Vector2.new(0.5, 1)
hand.BackgroundTransparency = 1
hand.Parent = gui

local handLayout = Instance.new("UIListLayout")
handLayout.FillDirection = Enum.FillDirection.Horizontal
handLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
handLayout.Padding = UDim.new(0, 8)
handLayout.Parent = hand

-- ---------- state rendering ----------
local myCycles = 0
local picked = false

local function buffTags(c): string
	local extras = {}
	if c.blades > 0 then
		table.insert(extras, ("B%d"):format(c.blades))
	end
	if c.shields > 0 then
		table.insert(extras, ("S%d"):format(c.shields))
	end
	if c.dots > 0 then
		table.insert(extras, ("DoT%d"):format(c.dots))
	end
	return table.concat(extras, " ")
end

local function refreshTargets(livingEnemies)
	for _, child in targetFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if #livingEnemies < 2 then
		selectedTarget = 1
		return
	end
	if selectedTarget > #livingEnemies then
		selectedTarget = 1
	end
	for slot, enemy in livingEnemies do
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(0.3, 1)
		button.BackgroundColor3 = slot == selectedTarget and Color3.fromRGB(90, 25, 25) or Color3.fromRGB(25, 25, 40)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.Code
		button.Text = ("T%d %d"):format(slot, enemy.health)
		local stroke = Instance.new("UIStroke")
		stroke.Color = slot == selectedTarget and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(70, 70, 80)
		stroke.Thickness = 2
		stroke.Parent = button
		button.Activated:Connect(function()
			selectedTarget = slot
			refreshTargets(livingEnemies)
		end)
		button.Parent = targetFrame
	end
end

local function updateBars(state, isPvP)
	local allies = {}
	local enemyName, enemyTags = "Enemy", ""
	local enemyHealth, enemyMax, enemyAlive = 0, 0, 0
	local livingEnemies = {}
	for _, c in state.combatants do
		-- in PvP the "enemy side" is the other player
		if c.isPlayer and not (isPvP and c.name ~= player.Name) then
			if c.name == player.Name then
				playerBar.Fill.Size = UDim2.fromScale(math.max(0, c.health / c.maxHealth), 1)
				playerBar.Label.Text = ("%s  %d/%d  %s"):format(c.name, c.health, c.maxHealth, buffTags(c))
				myCycles = c.cycles
			else
				table.insert(allies, ("%s %d/%d"):format(c.name, c.health, c.maxHealth))
			end
		else
			enemyName = c.name
			enemyHealth += c.health
			enemyMax += c.maxHealth
			if c.health > 0 then
				enemyAlive += 1
				enemyTags = buffTags(c)
				table.insert(livingEnemies, c)
			end
		end
	end
	refreshTargets(livingEnemies)
	enemyBar.Fill.Size = UDim2.fromScale(enemyMax > 0 and math.max(0, enemyHealth / enemyMax) or 0, 1)
	local countText = enemyAlive > 1 and (" x%d"):format(enemyAlive) or ""
	enemyBar.Label.Text = ("%s%s  %d/%d  %s"):format(enemyName, countText, enemyHealth, enemyMax, enemyTags)
	allyLabel.Text = #allies > 0 and ("ALLIES: " .. table.concat(allies, "  ")) or ""
end

local function clearHand()
	for _, child in hand:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function showHand(deck)
	clearHand()
	picked = false
	for _, spellId in deck do
		local spell = SpellData[spellId]
		local affordable = spell.cost <= myCycles

		local card = Instance.new("TextButton")
		card.Size = UDim2.fromScale(0.13, 1)
		card.BackgroundColor3 = affordable and Color3.fromRGB(25, 25, 40) or Color3.fromRGB(15, 15, 18)
		card.TextColor3 = affordable and Color3.new(1, 1, 1) or Color3.fromRGB(90, 90, 90)
		card.TextWrapped = true
		card.TextSize = 14
		card.Font = Enum.Font.Code
		card.Text = ("%s\n[%d cyc] %d%%\n%s"):format(spell.name, spell.cost, spell.accuracy, spell.description)
		card.Parent = hand

		local stroke = Instance.new("UIStroke")
		stroke.Color = SCHOOL_COLORS[spell.school] or Color3.new(1, 1, 1)
		stroke.Thickness = 2
		stroke.Parent = card

		if affordable then
			card.Activated:Connect(function()
				if picked then
					return
				end
				picked = true
				castRequest:FireServer(spellId, selectedTarget)
				statusLabel.Text = "Casting " .. spell.name .. "..."
				clearHand()
			end)
		end
	end
end

-- ---------- server events ----------
battleState.OnClientEvent:Connect(function(payload)
	gui.Enabled = true
	updateBars(payload.state, payload.pvp)
	if payload.phase == "select" then
		statusLabel.Text = ("ROUND %d — pick a card! (%d cycles)"):format(payload.state.round + 1, myCycles)
		showHand(payload.deck)
	else
		statusLabel.Text = "Resolving..."
		clearHand()
		local events = payload.state.events
		if events and #events > 0 then
			logLabel.Text = table.concat(events, "\n")
			logLabel.Visible = true
			task.delay(3, function()
				logLabel.Visible = false
			end)
		end
	end
end)

battleEnd.OnClientEvent:Connect(function(payload)
	statusLabel.Text = payload.won
			and ("FLATLINED THEM! +%d XP, +%d credits"):format(payload.xp or 0, payload.credits or 0)
		or "You got flatlined..."
	clearHand()
	task.delay(3, function()
		gui.Enabled = false
	end)
end)
