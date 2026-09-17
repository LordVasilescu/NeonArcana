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

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromScale(0.4, 0.07)
statusLabel.Position = UDim2.fromScale(0.5, 0.02)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(120, 255, 220)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Code
statusLabel.Parent = gui

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

local function updateBars(state)
	for _, c in state.combatants do
		local bar = c.isPlayer and playerBar or enemyBar
		bar.Fill.Size = UDim2.fromScale(math.max(0, c.health / c.maxHealth), 1)
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
		bar.Label.Text = ("%s  %d/%d  %s"):format(c.name, c.health, c.maxHealth, table.concat(extras, " "))
		if c.isPlayer then
			myCycles = c.cycles
		end
	end
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
				castRequest:FireServer(spellId)
				statusLabel.Text = "Casting " .. spell.name .. "..."
				clearHand()
			end)
		end
	end
end

-- ---------- server events ----------
battleState.OnClientEvent:Connect(function(payload)
	gui.Enabled = true
	updateBars(payload.state)
	if payload.phase == "select" then
		statusLabel.Text = ("ROUND %d — pick a card! (%d cycles)"):format(payload.state.round + 1, myCycles)
		showHand(payload.deck)
	else
		statusLabel.Text = "Resolving..."
		clearHand()
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
