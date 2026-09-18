--!nonstrict
-- BattleRunner: shared battle circles, W101-style. First toucher starts the fight;
-- up to 3 more players can join mid-battle by touching the same pad — each joiner
-- pulls in another enemy (max 4v4). Late joiners get catch-up cycles.

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
local MAX_HEROES = 4
local CATCHUP_CAP = 5

local BattleRunner = {}
local battles = {} -- padKey -> rec
local inBattle = {} -- player -> rec

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

local function firstLivingEnemyIndex(battle): number?
	for i, c in battle.combatants do
		if c.player == nil and c.health > 0 then
			return i
		end
	end
	return nil
end

local function countTeams(battle): (number, number)
	local heroes, enemies = 0, 0
	for _, c in battle.combatants do
		if c.health > 0 then
			if c.player then
				heroes += 1
			else
				enemies += 1
			end
		end
	end
	return heroes, enemies
end

local function broadcast(rec, payload)
	for player, hero in rec.heroes do
		if player.Parent and (payload.phase ~= "select" or hero.health > 0) then
			if payload.phase == "select" then
				payload.deck = hero.deck
			end
			battleState:FireClient(player, payload)
		end
	end
end

local function announce(rec, text)
	for player in rec.heroes do
		if player.Parent then
			PlayerDataService.notify(player, text)
		end
	end
end

local function addHero(rec, player)
	local profile = PlayerDataService.get(player)
	local level = (profile and profile.level) or 1
	local gearHP, gearAcc, gearPower = PlayerDataService.getGearStats(player)
	local heroHP = BASE_HP + HP_PER_LEVEL * (level - 1) + gearHP
	local heroPower = math.min(0.05 + 0.025 * (level - 1) + gearPower, 0.6)

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
	hero.cycles = math.min(1 + rec.battle.round, CATCHUP_CAP)
	table.insert(rec.battle.combatants, hero)
	rec.heroes[player] = hero
	rec.heroIndex[player] = #rec.battle.combatants
	rec.treasure[player] = treasureInHand
	inBattle[player] = rec
end

local function addEnemy(rec)
	local def = EnemyData[rec.enemyType]
	local foe = CombatService.newCombatant(nil, def.name, def.health, table.clone(def.deck), def.boss and 0.25 or 0.1)
	foe.cycles = math.min(1 + rec.battle.round, CATCHUP_CAP)
	table.insert(rec.battle.combatants, foe)
	rec.enemyCount += 1
end

local function finishBattle(rec, won: boolean)
	local def = EnemyData[rec.enemyType]
	for player, hero in rec.heroes do
		if player.Parent then
			local xpGain, creditGain = 0, 0
			if won then
				xpGain = def.xp * rec.enemyCount
				creditGain = def.credits * rec.enemyCount
				PlayerDataService.addXP(player, xpGain)
				PlayerDataService.addCredits(player, creditGain)
				for _ = 1, rec.enemyCount do
					if def.drops then
						for _, drop in def.drops do
							if math.random() < drop.chance then
								PlayerDataService.awardGear(player, drop.gear)
							end
						end
					end
					PlayerDataService.recordKill(player, rec.enemyType)
				end
			end
			battleEnd:FireClient(player, { won = won, xp = xpGain, credits = creditGain })
			if not won or hero.health <= 0 then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					root.CFrame = CFrame.new(0, 5, 10)
				end
			end
		end
		inBattle[player] = nil
	end
	battles[rec.padKey] = nil
end

local function runBattle(rec)
	local battle = rec.battle
	while battle.active do
		broadcast(rec, { phase = "select", selectTime = CombatService.SELECT_TIME, state = snapshot(battle) })

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

		-- remember hero casts for treasure burn
		local casts = {}
		for player, hero in rec.heroes do
			casts[player] = hero.pendingCast
		end

		-- each living enemy targets a random living hero
		for i, c in battle.combatants do
			if c.player == nil and c.health > 0 then
				local heroSlots = {}
				for j, h in battle.combatants do
					if h.player and h.health > 0 then
						table.insert(heroSlots, j)
					end
				end
				if #heroSlots > 0 then
					npcPick(battle, i, heroSlots[math.random(#heroSlots)])
				end
			end
		end

		CombatService.resolveRound(battle)

		for player, castId in casts do
			local treasure = rec.treasure[player]
			if castId and treasure and treasure[castId] then
				treasure[castId] = nil
				local hero = rec.heroes[player]
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
		end

		broadcast(rec, { phase = "resolve", state = snapshot(battle) })
		task.wait(RESOLVE_PAUSE)

		local heroesAlive, enemiesAlive = countTeams(battle)
		if heroesAlive == 0 or enemiesAlive == 0 then
			battle.active = false
			finishBattle(rec, enemiesAlive == 0)
		end
	end
end

function BattleRunner.isBusy(player): boolean
	return inBattle[player] ~= nil
end

-- Touch handler: start a battle at this pad, or join the one in progress.
function BattleRunner.requestJoin(player: Player, enemyId: string, padKey: string)
	if inBattle[player] then
		return
	end
	local def = EnemyData[enemyId]
	if not def then
		warn("[BattleRunner] unknown enemy: " .. tostring(enemyId))
		return
	end

	local rec = battles[padKey]
	if rec then
		if not rec.battle.active or rec.enemyType ~= enemyId then
			return
		end
		local heroCount = 0
		for _ in rec.heroes do
			heroCount += 1
		end
		if heroCount >= MAX_HEROES then
			PlayerDataService.notify(player, "That fight is full (4 max).")
			return
		end
		addHero(rec, player)
		addEnemy(rec)
		announce(rec, ("%s joined the fight — another %s jacks in!"):format(player.Name, def.name))
		return
	end

	rec = {
		padKey = padKey,
		enemyType = enemyId,
		heroes = {},
		heroIndex = {},
		treasure = {},
		enemyCount = 0,
		battle = CombatService.newBattle({}),
	}
	battles[padKey] = rec
	addHero(rec, player)
	addEnemy(rec)
	task.spawn(runBattle, rec)
end

-- Back-compat shim for anything still calling startBattle.
function BattleRunner.startBattle(player: Player, enemyId: string)
	BattleRunner.requestJoin(player, enemyId, "solo_" .. player.Name)
end

function BattleRunner.init()
	castRequest.OnServerEvent:Connect(function(player, spellId)
		local rec = inBattle[player]
		if not rec or typeof(spellId) ~= "string" then
			return
		end
		local casterIndex = rec.heroIndex[player]
		local targetIndex = firstLivingEnemyIndex(rec.battle)
		if casterIndex and targetIndex then
			CombatService.requestCast(rec.battle, casterIndex, spellId, targetIndex)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local rec = inBattle[player]
		if rec then
			local hero = rec.heroes[player]
			if hero then
				hero.health = 0 -- leaver counts as downed
			end
			rec.heroes[player] = nil
			rec.heroIndex[player] = nil
			inBattle[player] = nil
		end
	end)
end

return BattleRunner
