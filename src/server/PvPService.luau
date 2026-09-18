--!nonstrict
-- PvPService: plaza duel pad. First toucher waits, second toucher starts a duel.
-- Pure bragging rights — no XP, credits, or drops. Reuses CombatService + the
-- same client combat UI (payloads carry pvp=true so the UI sides correctly).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatService = require(script.Parent.CombatService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BattleRunner = require(script.Parent.BattleRunner)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRequest = remotes:WaitForChild("CastRequest")
local battleState = remotes:WaitForChild("BattleState")
local battleEnd = remotes:WaitForChild("BattleEnd")

local RESOLVE_PAUSE = 1.5
local BASE_HP = 400
local HP_PER_LEVEL = 30

local PvPService = {}
local waiting: Player? = nil
local duels = {} -- player -> rec

local function snapshot(battle)
	local combatants = {}
	for _, c in battle.combatants do
		table.insert(combatants, {
			name = c.name,
			health = c.health,
			maxHealth = c.maxHealth,
			cycles = c.cycles,
			isPlayer = c.player ~= nil,
			blades = #c.blades,
			shields = #c.shields,
			traps = #c.traps,
			dots = #c.dots,
		})
	end
	return { round = battle.round, active = battle.active, combatants = combatants, events = battle.lastEvents }
end

local function makeHero(player)
	local profile = PlayerDataService.get(player)
	local level = (profile and profile.level) or 1
	local gearHP, gearAcc, gearPower = PlayerDataService.getGearStats(player)
	local hero = CombatService.newCombatant(
		player,
		player.Name,
		BASE_HP + HP_PER_LEVEL * (level - 1) + gearHP,
		PlayerDataService.getDeck(player),
		math.min(0.05 + 0.025 * (level - 1) + gearPower, 0.6),
		gearAcc
	)
	hero.cycles = 1
	return hero
end

local function runDuel(playerA, playerB)
	local heroA, heroB = makeHero(playerA), makeHero(playerB)
	local battle = CombatService.newBattle({})
	table.insert(battle.combatants, heroA)
	table.insert(battle.combatants, heroB)
	local rec =
		{ battle = battle, index = { [playerA] = 1, [playerB] = 2 }, heroes = { [playerA] = heroA, [playerB] = heroB } }
	duels[playerA] = rec
	duels[playerB] = rec

	for player in rec.index do
		PlayerDataService.notify(player, "DUEL START! No stakes but pride, choom.")
	end

	while battle.active do
		for player, hero in rec.heroes do
			if player.Parent and hero.health > 0 then
				battleState:FireClient(player, {
					phase = "select",
					selectTime = CombatService.SELECT_TIME,
					deck = hero.deck,
					state = snapshot(battle),
					pvp = true,
				})
			end
		end
		local deadline = os.clock() + CombatService.SELECT_TIME
		while battle.active and os.clock() < deadline do
			local allPicked = true
			for player, hero in rec.heroes do
				if player.Parent and hero.health > 0 and not hero.pendingCast then
					allPicked = false
					break
				end
			end
			if allPicked then
				break
			end
			task.wait(0.1)
		end

		CombatService.resolveRound(battle)
		for player in rec.index do
			if player.Parent then
				battleState:FireClient(player, { phase = "resolve", state = snapshot(battle), pvp = true })
			end
		end
		task.wait(RESOLVE_PAUSE)

		if heroA.health <= 0 or heroB.health <= 0 or not playerA.Parent or not playerB.Parent then
			battle.active = false
		end
	end

	local winner = heroA.health > 0 and playerA or playerB
	for player in rec.index do
		duels[player] = nil
		if player.Parent then
			battleEnd:FireClient(player, { won = player == winner, xp = 0, credits = 0 })
			PlayerDataService.notify(
				player,
				player == winner and "DUEL WON. The Plaza saw everything." or "Duel lost. Run it back."
			)
		end
	end
end

function PvPService.init()
	castRequest.OnServerEvent:Connect(function(player, spellId)
		local rec = duels[player]
		if not rec or typeof(spellId) ~= "string" then
			return
		end
		local casterIndex = rec.index[player]
		local targetIndex = casterIndex == 1 and 2 or 1
		CombatService.requestCast(rec.battle, casterIndex, spellId, targetIndex)
	end)

	local pad = Instance.new("Part")
	pad.Name = "PvPArena"
	pad.Anchored = true
	pad.Size = Vector3.new(10, 1, 10)
	pad.Position = Vector3.new(-14, 1.3, -22)
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(255, 60, 120)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(12, 3)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 60, 120)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = "PVP DUEL PAD\n(2 players)"
	label.Parent = gui
	gui.Parent = pad
	pad.Parent = Workspace

	local debounce = {}
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or debounce[player] or duels[player] or BattleRunner.isBusy(player) then
			return
		end
		debounce[player] = true
		task.delay(2, function()
			debounce[player] = nil
		end)

		if waiting == player then
			return
		end
		if waiting and waiting.Parent and not duels[waiting] then
			local challenger = waiting
			waiting = nil
			task.spawn(runDuel, challenger, player)
		else
			waiting = player
			PlayerDataService.notify(player, "Waiting for a challenger... (second player touches the pad)")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if waiting == player then
			waiting = nil
		end
		local rec = duels[player]
		if rec then
			local hero = rec.heroes[player]
			if hero then
				hero.health = 0
			end
		end
	end)
end

return PvPService
