--!strict
-- CombatService: server-authoritative turn-based combat, Wizard101-style.
-- Round flow: everyone picks a card (timed) -> resolve in speed order -> repeat.
-- MVP: 1v1 player vs NPC. Extend `Combatant` list for 4v4 later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpellData = require(ReplicatedStorage.Shared.SpellData)

local CombatService = {}

local SELECT_TIME = 20 -- seconds to pick a card each round
local rng = Random.new()

export type Combatant = {
	player: Player?, -- nil = NPC
	name: string,
	maxHealth: number,
	health: number,
	cycles: number, -- pips
	blades: { { school: string, amount: number } },
	traps: { { amount: number } },
	shields: { { amount: number } },
	dots: { { amount: number, ticksLeft: number } },
	deck: { string }, -- spell ids
	pendingCast: string?, -- chosen this round
	pendingTarget: number?, -- index into combatants
}

export type Battle = {
	combatants: { Combatant },
	round: number,
	active: boolean,
}

function CombatService.newCombatant(player: Player?, name: string, health: number, deck: { string }): Combatant
	return {
		player = player,
		name = name,
		maxHealth = health,
		health = health,
		cycles = 0,
		blades = {},
		traps = {},
		shields = {},
		dots = {},
		deck = deck,
		pendingCast = nil,
		pendingTarget = nil,
	}
end

-- Server validates every cast request: card in deck, enough cycles, battle live.
function CombatService.requestCast(battle: Battle, casterIndex: number, spellId: string, targetIndex: number): boolean
	local caster = battle.combatants[casterIndex]
	if not battle.active or not caster then
		return false
	end
	if not table.find(caster.deck, spellId) then
		return false
	end
	local spell = SpellData[spellId]
	if not spell then
		return false
	end
	if spell.cost > caster.cycles then
		return false
	end
	if not battle.combatants[targetIndex] then
		return false
	end
	caster.pendingCast = spellId
	caster.pendingTarget = targetIndex
	return true
end

local function applySpell(_battle: Battle, caster: Combatant, spell: SpellData.Spell, target: Combatant)
	-- Fizzle check (the W101 accuracy gamble)
	if rng:NextNumber(0, 100) > spell.accuracy then
		return { fizzled = true }
	end

	for _, effect in spell.effects do
		if effect.kind == "Blade" then
			table.insert(caster.blades, { school = spell.school, amount = effect.amount })
		elseif effect.kind == "Trap" then
			table.insert(target.traps, { amount = effect.amount })
		elseif effect.kind == "Shield" then
			table.insert(caster.shields, { amount = effect.amount })
		elseif effect.kind == "Heal" then
			caster.health = math.min(caster.maxHealth, caster.health + effect.amount)
		elseif effect.kind == "Damage" or effect.kind == "DoT" then
			local dmg = effect.amount
			-- consume blades matching school (multiplicative stacking = the depth)
			for i = #caster.blades, 1, -1 do
				if caster.blades[i].school == spell.school then
					dmg *= (1 + caster.blades[i].amount / 100)
					table.remove(caster.blades, i)
				end
			end
			-- consume traps on target
			for i = #target.traps, 1, -1 do
				dmg *= (1 + target.traps[i].amount / 100)
				table.remove(target.traps, i)
			end
			-- consume one shield
			if #target.shields > 0 then
				dmg *= (1 - target.shields[1].amount / 100)
				table.remove(target.shields, 1)
			end
			dmg = math.floor(dmg)
			if effect.kind == "DoT" then
				table.insert(target.dots, { amount = dmg, ticksLeft = effect.ticks or 3 })
			else
				target.health = math.max(0, target.health - dmg)
			end
		end
	end
	return { fizzled = false }
end

-- Call once per round after all picks are in (or SELECT_TIME expires).
function CombatService.resolveRound(battle: Battle)
	battle.round += 1

	-- DoT ticks first
	for _, c in battle.combatants do
		for i = #c.dots, 1, -1 do
			c.health = math.max(0, c.health - c.dots[i].amount)
			c.dots[i].ticksLeft -= 1
			if c.dots[i].ticksLeft <= 0 then
				table.remove(c.dots, i)
			end
		end
	end

	-- Resolve casts in order (later: sort by speed/school)
	for _, caster in battle.combatants do
		if caster.health > 0 and caster.pendingCast then
			local spell = SpellData[caster.pendingCast]
			local target = battle.combatants[caster.pendingTarget :: number]
			if spell and target and target.health > 0 then
				caster.cycles -= spell.cost
				applySpell(battle, caster, spell, target)
			end
		end
		caster.pendingCast = nil
		caster.pendingTarget = nil
	end

	-- Gain a cycle (power cycle chance later, scaling with level)
	for _, c in battle.combatants do
		if c.health > 0 then
			c.cycles += 1
		end
	end

	-- Win check
	local alive = 0
	for _, c in battle.combatants do
		if c.health > 0 then
			alive += 1
		end
	end
	if alive <= 1 then
		battle.active = false
	end
end

function CombatService.newBattle(combatants: { Combatant }): Battle
	local battle: Battle = { combatants = combatants, round = 0, active = true }
	for _, c in combatants do
		c.cycles = 1 -- everyone starts with one cycle
	end
	return battle
end

CombatService.SELECT_TIME = SELECT_TIME
return CombatService
