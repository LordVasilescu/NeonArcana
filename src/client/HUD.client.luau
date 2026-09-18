--!nonstrict
-- HUD: level/XP/credits/crowns bar, quest tracker, toasts, zone purchase dialog,
-- and the first-join school selection screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SchoolColors = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SchoolColors"))
local SpellData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpellData"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local hudUpdate = remotes:WaitForChild("HUDUpdate")
local notifyRemote = remotes:WaitForChild("Notify")
local unlockZone = remotes:WaitForChild("UnlockZone")
local selectSchool = remotes:WaitForChild("SelectSchool")
local deckUpdate = remotes:WaitForChild("DeckUpdate")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function codeLabel(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	for k, v in props do
		label[k] = v
	end
	label.Parent = parent
	return label
end

-- top-left stats
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.fromScale(0.22, 0.12)
statsFrame.Position = UDim2.fromScale(0.01, 0.01)
statsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsFrame.BackgroundTransparency = 0.3
statsFrame.BorderSizePixel = 0
statsFrame.Parent = gui

local levelLabel = codeLabel(statsFrame, { Size = UDim2.fromScale(1, 0.34), TextXAlignment = Enum.TextXAlignment.Left })
local creditsLabel = codeLabel(statsFrame, {
	Size = UDim2.fromScale(1, 0.33),
	Position = UDim2.fromScale(0, 0.34),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(120, 255, 220),
})
local crownsLabel = codeLabel(statsFrame, {
	Size = UDim2.fromScale(1, 0.33),
	Position = UDim2.fromScale(0, 0.67),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(255, 220, 80),
})

-- quest tracker, top-center
local questLabel = codeLabel(gui, {
	Size = UDim2.fromScale(0.4, 0.045),
	Position = UDim2.fromScale(0.5, 0.01),
	AnchorPoint = Vector2.new(0.5, 0),
	TextColor3 = Color3.fromRGB(255, 220, 80),
})

-- toast, center
local toastLabel = codeLabel(gui, {
	Size = UDim2.fromScale(0.5, 0.06),
	Position = UDim2.fromScale(0.5, 0.25),
	AnchorPoint = Vector2.new(0.5, 0),
	TextColor3 = Color3.fromRGB(120, 255, 220),
	Visible = false,
})
local toastToken = 0
local function toast(text)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(3.5, function()
		if toastToken == token then
			toastLabel.Visible = false
		end
	end)
end

-- zone purchase dialog
local dialog = Instance.new("Frame")
dialog.Size = UDim2.fromScale(0.34, 0.22)
dialog.Position = UDim2.fromScale(0.5, 0.5)
dialog.AnchorPoint = Vector2.new(0.5, 0.5)
dialog.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
dialog.BorderSizePixel = 0
dialog.Visible = false
dialog.Parent = gui
local dialogStroke = Instance.new("UIStroke")
dialogStroke.Color = Color3.fromRGB(255, 60, 120)
dialogStroke.Thickness = 2
dialogStroke.Parent = dialog

local dialogText = codeLabel(dialog, { Size = UDim2.fromScale(0.9, 0.45), Position = UDim2.fromScale(0.05, 0.05) })
local pendingZoneId = nil

local function dialogButton(text, xPos, color)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(0.4, 0.3)
	button.Position = UDim2.fromScale(xPos, 0.6)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(0, 0, 0)
	button.TextScaled = true
	button.Font = Enum.Font.Code
	button.Text = text
	button.Parent = dialog
	return button
end

local buyButton = dialogButton("UNLOCK", 0.07, Color3.fromRGB(255, 220, 80))
local cancelButton = dialogButton("LATER", 0.53, Color3.fromRGB(120, 120, 140))

buyButton.Activated:Connect(function()
	if pendingZoneId then
		unlockZone:FireServer(pendingZoneId)
	end
	dialog.Visible = false
end)
cancelButton.Activated:Connect(function()
	dialog.Visible = false
end)

-- ---------- deck editor ----------
local latestOwned = {}
local latestDeck = {}
local selectedCards = {}

local deckButton = Instance.new("TextButton")
deckButton.Size = UDim2.fromScale(0.08, 0.05)
deckButton.Position = UDim2.fromScale(0.01, 0.14)
deckButton.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
deckButton.TextColor3 = Color3.fromRGB(200, 80, 255)
deckButton.TextScaled = true
deckButton.Font = Enum.Font.Code
deckButton.Text = "DECK"
deckButton.Parent = gui
local deckStroke = Instance.new("UIStroke")
deckStroke.Color = Color3.fromRGB(200, 80, 255)
deckStroke.Thickness = 2
deckStroke.Parent = deckButton

local deckPanel = Instance.new("Frame")
deckPanel.Size = UDim2.fromScale(0.6, 0.6)
deckPanel.Position = UDim2.fromScale(0.5, 0.5)
deckPanel.AnchorPoint = Vector2.new(0.5, 0.5)
deckPanel.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
deckPanel.BorderSizePixel = 0
deckPanel.Visible = false
deckPanel.ZIndex = 4
deckPanel.Parent = gui
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(200, 80, 255)
panelStroke.Thickness = 2
panelStroke.Parent = deckPanel

local deckTitle = codeLabel(deckPanel, {
	Size = UDim2.fromScale(0.9, 0.1),
	Position = UDim2.fromScale(0.05, 0.03),
	Text = "DECK EDITOR",
	TextColor3 = Color3.fromRGB(200, 80, 255),
	ZIndex = 4,
})

local cardGrid = Instance.new("Frame")
cardGrid.Size = UDim2.fromScale(0.94, 0.62)
cardGrid.Position = UDim2.fromScale(0.03, 0.15)
cardGrid.BackgroundTransparency = 1
cardGrid.ZIndex = 4
cardGrid.Parent = deckPanel
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromScale(0.24, 0.3)
gridLayout.CellPadding = UDim2.fromScale(0.008, 0.02)
gridLayout.Parent = cardGrid

local function refreshDeckGrid()
	for _, child in cardGrid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local count = 0
	for _ in selectedCards do
		count += 1
	end
	deckTitle.Text = ("DECK EDITOR — %d/7 loaded (min 3)"):format(count)
	for _, spellId in latestOwned do
		local spell = SpellData[spellId]
		local card = Instance.new("TextButton")
		local picked = selectedCards[spellId] == true
		card.BackgroundColor3 = picked and Color3.fromRGB(45, 30, 60) or Color3.fromRGB(20, 20, 32)
		card.TextColor3 = picked and Color3.new(1, 1, 1) or Color3.fromRGB(140, 140, 150)
		card.TextWrapped = true
		card.TextSize = 14
		card.Font = Enum.Font.Code
		card.Text = ("%s\n[%d cyc] %d%%%s"):format(spell.name, spell.cost, spell.accuracy, picked and "\nLOADED" or "")
		card.ZIndex = 4
		local stroke = Instance.new("UIStroke")
		stroke.Color = picked and (SchoolColors[spell.school] or Color3.new(1, 1, 1)) or Color3.fromRGB(60, 60, 70)
		stroke.Thickness = picked and 3 or 1
		stroke.Parent = card
		card.Activated:Connect(function()
			if selectedCards[spellId] then
				selectedCards[spellId] = nil
			else
				local n = 0
				for _ in selectedCards do
					n += 1
				end
				if n >= 7 then
					return
				end
				selectedCards[spellId] = true
			end
			refreshDeckGrid()
		end)
		card.Parent = cardGrid
	end
end

local function deckPanelButton(text, xPos, color)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(0.25, 0.1)
	button.Position = UDim2.fromScale(xPos, 0.85)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(0, 0, 0)
	button.TextScaled = true
	button.Font = Enum.Font.Code
	button.Text = text
	button.ZIndex = 4
	button.Parent = deckPanel
	return button
end

local saveDeckButton = deckPanelButton("SAVE DECK", 0.22, Color3.fromRGB(120, 255, 220))
local closeDeckButton = deckPanelButton("CLOSE", 0.53, Color3.fromRGB(120, 120, 140))

deckButton.Activated:Connect(function()
	selectedCards = {}
	for _, id in latestDeck do
		selectedCards[id] = true
	end
	refreshDeckGrid()
	deckPanel.Visible = true
end)
saveDeckButton.Activated:Connect(function()
	local list = {}
	for id in selectedCards do
		table.insert(list, id)
	end
	deckUpdate:FireServer(list)
	deckPanel.Visible = false
end)
closeDeckButton.Activated:Connect(function()
	deckPanel.Visible = false
end)

-- school selection (first join)
local schoolFrame = Instance.new("Frame")
schoolFrame.Size = UDim2.fromScale(1, 1)
schoolFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 12)
schoolFrame.BackgroundTransparency = 0.15
schoolFrame.Visible = false
schoolFrame.ZIndex = 5
schoolFrame.Parent = gui

codeLabel(schoolFrame, {
	Size = UDim2.fromScale(0.8, 0.1),
	Position = UDim2.fromScale(0.1, 0.08),
	Text = "CHOOSE YOUR PROTOCOL, CODESLINGER",
	TextColor3 = Color3.fromRGB(120, 255, 220),
	ZIndex = 5,
})

local SCHOOL_INFO = {
	{ "Burnout", "Damage over time. Watch them cook." },
	{ "Coolant", "Shields and staying power." },
	{ "Surge", "Huge damage. When it hits." },
	{ "Patch", "Outheal everything." },
	{ "Leech", "Their health is your health." },
	{ "Ghost", "Double hits and tricks." },
	{ "Kernel", "A bit of everything." },
}

local schoolList = Instance.new("Frame")
schoolList.Size = UDim2.fromScale(0.9, 0.6)
schoolList.Position = UDim2.fromScale(0.05, 0.25)
schoolList.BackgroundTransparency = 1
schoolList.ZIndex = 5
schoolList.Parent = schoolFrame
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = schoolList

for _, info in SCHOOL_INFO do
	local name, desc = info[1], info[2]
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(0.13, 0.8)
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextWrapped = true
	button.TextSize = 16
	button.Font = Enum.Font.Code
	button.Text = name:upper() .. "\n\n" .. desc
	button.ZIndex = 5
	button.Parent = schoolList
	local stroke = Instance.new("UIStroke")
	stroke.Color = SchoolColors[name]
	stroke.Thickness = 3
	stroke.Parent = button
	button.Activated:Connect(function()
		selectSchool:FireServer(name)
		schoolFrame.Visible = false
	end)
end

-- server events
local schoolChosen = false
hudUpdate.OnClientEvent:Connect(function(data)
	latestOwned = data.ownedCards or {}
	latestDeck = data.deck or {}
	levelLabel.Text = ("LVL %d  XP %d/%d  %s"):format(data.level, data.xp, data.xpNeeded, data.school or "")
	creditsLabel.Text = ("CREDITS %d"):format(data.credits)
	crownsLabel.Text = ("CROWNS %d"):format(data.crowns)
	questLabel.Text = data.questText or ""
	if data.school then
		schoolChosen = true
		schoolFrame.Visible = false
	elseif not schoolChosen then
		schoolFrame.Visible = true
	end
end)

notifyRemote.OnClientEvent:Connect(function(data)
	if data.offer then
		pendingZoneId = data.offer.zoneId
		dialogText.Text = ("%s\nUnlock for %d CROWNS?"):format(data.offer.name, data.offer.cost)
		dialog.Visible = true
	end
	if data.text then
		toast(data.text)
	end
end)
