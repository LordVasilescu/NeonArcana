--!nonstrict
-- EnemySpawner: places enemy pads along each street. Step on one -> battle starts.
-- The hub DuelPad stays as a free sparring pad vs a Chrome Ganger.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local EnemyData = require(ReplicatedStorage.Shared.EnemyData)
local SchoolColors = require(ReplicatedStorage.Shared.SchoolColors)
local BattleRunner = require(script.Parent.BattleRunner)
local MeshVisuals = require(script.Parent.MeshVisuals)

local PAD_COOLDOWN = 5

local EnemySpawner = {}

local function hookPad(pad: BasePart, enemyId: string)
	local cooling = false
	pad.Touched:Connect(function(hit)
		if cooling then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not BattleRunner.isBusy(player) then
			cooling = true
			local originalTransparency = pad.Transparency
			pad.Transparency = 0.8
			BattleRunner.startBattle(player, enemyId)
			task.delay(PAD_COOLDOWN, function()
				pad.Transparency = originalTransparency
				cooling = false
			end)
		end
	end)
end

local function makePad(enemyId: string, position: Vector3, parent: Instance)
	local enemy = EnemyData[enemyId]
	local pad = Instance.new("Part")
	pad.Name = "EnemyPad_" .. enemyId
	pad.Anchored = true
	pad.Size = enemy.boss and Vector3.new(14, 1, 14) or Vector3.new(8, 1, 8)
	pad.Position = position + Vector3.new(0, 0.6, 0)
	pad.Material = Enum.Material.Neon
	pad.Color = SchoolColors[enemy.school] or Color3.new(1, 1, 1)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(12, 3)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = enemy.boss and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = ("%s — Lv %d"):format(enemy.name, enemy.level)
	label.Parent = gui
	gui.Parent = pad

	pad.Parent = parent
	hookPad(pad, enemyId)

	-- real Tripo model standing on the pad once uploaded; pad glow stays as the tell
	local fit = enemy.boss and Vector3.new(11, 13, 11) or Vector3.new(6, 7.5, 6)
	task.spawn(function()
		MeshVisuals.place(
			enemyId,
			CFrame.lookAt(pad.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, pad.Position.Y, 0)),
			fit,
			parent
		)
	end)
end

function EnemySpawner.init()
	local folder = Instance.new("Folder")
	folder.Name = "EnemyPads"
	folder.Parent = Workspace

	for _, zone in ZoneData.list do
		for _, padSpec in zone.pads do
			local position = zone.dir * (ZoneData.ROAD_START + ZoneData.ROAD_LENGTH * padSpec.at)
			makePad(padSpec.enemy, position, folder)
		end
	end

	-- hub sparring pad (the original DuelPad)
	local duelPad = Workspace:WaitForChild("DuelPad", 10)
	if duelPad then
		hookPad(duelPad, "chrome_ganger")
	end
end

return EnemySpawner
