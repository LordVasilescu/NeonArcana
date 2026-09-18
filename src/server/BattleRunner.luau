--!nonstrict
-- BattleRunner: owns live PvE battles. EnemySpawner calls startBattle(player, enemyId).
-- Round: client gets "select" phase + timer -> picks a card -> NPC picks -> resolve.
-- On win: XP + credits + quest progress via PlayerDataService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatService = require(script.Parent.CombatService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SpellData = require(ReplicatedStorage.Shared.SpellData)
local EnemyData = require(ReplicatedStorage.Shared.EnemyData)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRequest = remotes:WaitForChild("CastRequest")
local battleState = remotes:WaitForChild("BattleState")
local battleEnd = remotes:WaitForChild("BattleEnd")

local RESOLVE_PAUSE = 1.5
local BASE_HP = 400
local HP_PER_LEVEL = 30

local BattleRunner = {}
local inBattle: { [Player]: any } = {}

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

local function npcPick(battle, npcIndex, targetIndex)
	local npc = battle.combatants[npcIndex]
	local affordable = {}
	for _, id in npc.deck do
		if SpellData[id].cost <= npc.cycles then
			table.insert(affordable, id)
		end
	end
	if #affordable > 0 then
		CombatService.requestCast(battle, npcIndex, affordable[math.random(#affordable)], targetIndex)
	end
end

function BattleRunner.isBusy(player): boolean
	return inBattle[player] ~= nil
end

function BattleRunner.startBattle(player: Player, enemyId: string)
	if inBattle[player] then
		return
	end
	local enemyDef = EnemyData[enemyId]
	if not enemyDef then
		warn("[BattleRunner] unknown enemy: " .. tostring(enemyId))
		return
	end

	local profile = PlayerDataService.get(player)
	local level = (profile and profile.level) or 1
	local gearHP, gearAcc, gearPower = PlayerDataService.getGearStats(player)
	local heroHP = BASE_HP + HP_PER_LEVEL * (level - 1) + gearHP
	local heroPower = math.min(0.05 + 0.025 * (level - 1) + gearPower, 0.6) -- power pips grow with level + gear
	local foePower = enemyDef.boss and 0.25 or 0.1

	-- deck = custom loadout + any treasure cards not already in it (single-use)
	local deck = PlayerDataService.getDeck(player)
	local treasureInHand = {}
	if profile and profile.treasureCards then
		for cardId, count in profile.treasureCards do
			if count > 0 and SpellData[cardId] and not table.find(deck, cardId) then
				table.insert(deck, cardId)
				treasureInHand[cardId] = true
			end
		end
	end

	local hero = CombatService.newCombatant(player, player.Name, heroHP, deck, heroPower, gearAcc)
	local foe = CombatService.newCombatant(nil, enemyDef.name, enemyDef.health, table.clone(enemyDef.deck), foePower)
	local battle = CombatService.newBattle({ hero, foe })
	inBattle[player] = battle

	task.spawn(function()
		while battle.active and player.Parent do
			battleState:FireClient(player, {
				phase = "select",
				selectTime = CombatService.SELECT_TIME,
				deck = hero.deck,
				state = snapshot(battle),
			})

			local deadline = os.clock() + CombatService.SELECT_TIME
			while battle.active and player.Parent and os.clock() < deadline and not hero.pendingCast do
				task.wait(0.1)
			end

			local castId = hero.pendingCast
			npcPick(battle, 2, 1)
			CombatService.resolveRound(battle)

			-- treasure cards burn on cast (fizzle included, W101 rules)
			if castId and treasureInHand[castId] then
				treasureInHand[castId] = nil
				local slot = table.find(hero.deck, castId)
				if slot then
					table.remove(hero.deck, slot)
				end
				local prof = PlayerDataService.get(player)
				if prof and prof.treasureCards and prof.treasureCards[castId] then
					prof.treasureCards[castId] -= 1
					if prof.treasureCards[castId] <= 0 then
						prof.treasureCards[castId] = nil
					end
				end
			end

			battleState:FireClient(player, { phase = "resolve", state = snapshot(battle) })
			task.wait(RESOLVE_PAUSE)
		end

		local won = foe.health <= 0
		local xpGain, creditGain = 0, 0
		if won then
			xpGain, creditGain = enemyDef.xp, enemyDef.credits
			PlayerDataService.addXP(player, xpGain)
			PlayerDataService.addCredits(player, creditGain)
			if enemyDef.drops then
				for _, drop in enemyDef.drops do
					if math.random() < drop.chance then
						PlayerDataService.awardGear(player, drop.gear)
					end
				end
			end
			PlayerDataService.recordKill(player, enemyId) -- also pushes HUD
		end
		if player.Parent then
			battleEnd:FireClient(player, { won = won, xp = xpGain, credits = creditGain })
			if not won then
				-- W101 rules: you got flatlined, wake up back at the Plaza
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					root.CFrame = CFrame.new(0, 5, 10)
				end
			end
		end
		inBattle[player] = nil
	end)
end

function BattleRunner.init()
	castRequest.OnServerEvent:Connect(function(player, spellId)
		local battle = inBattle[player]
		if battle and typeof(spellId) == "string" then
			CombatService.requestCast(battle, 1, spellId, 2)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inBattle[player] = nil
	end)
end

return BattleRunner
