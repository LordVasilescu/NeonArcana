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
	return { round = battle.round, active = battle.active, combatants = combatants }
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
	local heroHP = BASE_HP + HP_PER_LEVEL * (level - 1)

	local hero = CombatService.newCombatant(player, player.Name, heroHP, PlayerDataService.getDeck(player))
	local foe = CombatService.newCombatant(nil, enemyDef.name, enemyDef.health, table.clone(enemyDef.deck))
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

			npcPick(battle, 2, 1)
			CombatService.resolveRound(battle)
			battleState:FireClient(player, { phase = "resolve", state = snapshot(battle) })
			task.wait(RESOLVE_PAUSE)
		end

		local won = foe.health <= 0
		local xpGain, creditGain = 0, 0
		if won then
			xpGain, creditGain = enemyDef.xp, enemyDef.credits
			PlayerDataService.addXP(player, xpGain)
			PlayerDataService.addCredits(player, creditGain)
			PlayerDataService.recordKill(player, enemyId) -- also pushes HUD
		end
		if player.Parent then
			battleEnd:FireClient(player, { won = won, xp = xpGain, credits = creditGain })
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
