--!nonstrict
-- HUD: level/XP/credits/crowns bar, quest tracker, toasts, zone purchase dialog,
-- and the first-join school selection screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SchoolColors = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SchoolColors"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local hudUpdate = remotes:WaitForChild("HUDUpdate")
local notifyRemote = remotes:WaitForChild("Notify")
local unlockZone = remotes:WaitForChild("UnlockZone")
local selectSchool = remotes:WaitForChild("SelectSchool")

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
