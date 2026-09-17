--!nonstrict
-- BattleRunner: owns the live PvE battle loop. Step on the DuelPad -> fight a Chrome Ganger.
-- Round: client gets "select" phase + timer -> picks a card -> NPC picks -> resolve -> repeat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatService = require(script.Parent.CombatService)
local SpellData = require(ReplicatedStorage.Shared.SpellData)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRequest = remotes:WaitForChild("CastRequest")
local battleState = remotes:WaitForChild("BattleState")
local battleEnd = remotes:WaitForChild("BattleEnd")

-- MVP: everyone gets the full starter deck. Deck-building comes later.
local PLAYER_DECK =
	{ "spark_jab", "thermal_bleed", "overclock_blade", "frost_packet", "firewall", "hotfix", "exploit_trap" }
local NPC_DECK = { "spark_jab", "frost_packet" }

local RESOLVE_PAUSE = 1.5 -- seconds to let the client animate the round result

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

local function runBattle(player: Player)
	local hero = CombatService.newCombatant(player, player.Name, 500, table.clone(PLAYER_DECK))
	local ganger = CombatService.newCombatant(nil, "Chrome Ganger", 400, table.clone(NPC_DECK))
	local battle = CombatService.newBattle({ hero, ganger })
	inBattle[player] = battle

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

	if player.Parent then
		battleEnd:FireClient(player, { won = ganger.health <= 0 })
	end
	inBattle[player] = nil
end

function BattleRunner.init()
	castRequest.OnServerEvent:Connect(function(player, spellId)
		local battle = inBattle[player]
		if battle and typeof(spellId) == "string" then
			-- player is always combatant 1, NPC is 2 (until group fights exist)
			CombatService.requestCast(battle, 1, spellId, 2)
		end
	end)

	local pad = Workspace:WaitForChild("DuelPad")
	local cooldown: { [Player]: boolean } = {}
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not inBattle[player] and not cooldown[player] then
			cooldown[player] = true
			task.spawn(function()
				runBattle(player)
				task.wait(3) -- step-off grace so you don't chain-trigger
				cooldown[player] = nil
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		inBattle[player] = nil
	end)
end

return BattleRunner
