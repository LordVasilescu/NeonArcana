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
local AdoptModel = require(script.Parent.AdoptModel)
local PremadeAssets = require(script.Parent.PremadeAssets)
local ServerStorage = game:GetService("ServerStorage")

local PAD_COOLDOWN = 5
-- Scale reference: a player character is ~5 studs tall. Mobs read as a head taller,
-- bosses roughly double.
local ENEMY_FIT = Vector3.new(5, 6.5, 5)
local BOSS_FIT = Vector3.new(9, 11, 9)

-- Studio-imported enemy models, scaled once and stashed as clone templates
local adoptTemplates: { [string]: Model } = {}

local function prepareTemplates()
	for enemyId, enemy in EnemyData do
		local fit = enemy.boss and BOSS_FIT or ENEMY_FIT
		local model = Workspace:FindFirstChild(enemyId)
		if not (model and model:IsA("Model")) and PremadeAssets.ids[enemyId] then
			model = PremadeAssets.load(PremadeAssets.ids[enemyId])
		end
		if model and model:IsA("Model") then
			if AdoptModel.scaleToFit(model, fit) then
				model.Parent = ServerStorage
				adoptTemplates[enemyId] = model
			end
		end
	end
end

local EnemySpawner = {}

local function hookPad(pad: BasePart, enemyId: string)
	local padKey = pad:GetFullName()
	local debounce: { [Player]: boolean } = {}
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not debounce[player] and not BattleRunner.isBusy(player) then
			debounce[player] = true
			task.delay(PAD_COOLDOWN, function()
				debounce[player] = nil
			end)
			-- starts a fight, or joins the one already running on this pad (4 max)
			BattleRunner.requestJoin(player, enemyId, padKey)
		end
	end)
end

local function makePad(enemyId: string, position: Vector3, parent: Instance)
	local enemy = EnemyData[enemyId]
	local pad = Instance.new("Part")
	pad.Name = "EnemyPad_" .. enemyId
	pad.Anchored = true
	-- flush floor overlay (top at 0.1), same level as the road: no step onto the pad
	pad.Size = enemy.boss and Vector3.new(14, 0.2, 14) or Vector3.new(8, 0.2, 8)
	pad.Position = Vector3.new(position.X, 0, position.Z)
	pad.Material = Enum.Material.Neon
	pad.Color = SchoolColors[enemy.school] or Color3.new(1, 1, 1)
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth

	pad.Parent = parent
	hookPad(pad, enemyId)

	-- real Tripo model standing on the pad; imported template first, cloud mesh fallback
	local stance = CFrame.lookAt(pad.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, pad.Position.Y + 0.1, 0))
	local template = adoptTemplates[enemyId]
	if template then
		AdoptModel.stamp(template, stance, parent)
		return
	end
	local fit = enemy.boss and BOSS_FIT or ENEMY_FIT
	task.spawn(function()
		MeshVisuals.place(enemyId, stance, fit, parent)
	end)
end

function EnemySpawner.init()
	prepareTemplates()
	local folder = Instance.new("Folder")
	folder.Name = "EnemyPads"
	folder.Parent = Workspace

	for _, zone in ZoneData.list do
		for _, padSpec in zone.pads do
			local position = zone.dir
				* ((zone.startOverride or ZoneData.ROAD_START) + ZoneData.ROAD_LENGTH * padSpec.at)
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
