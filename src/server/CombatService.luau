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
	powerChance: number, -- chance a round's cycle gain is worth 2 (power pips)
	accuracyBonus: number, -- flat % added to every card's accuracy (gear)
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
	lastEvents: { string },
}

function CombatService.newCombatant(
	player: Player?,
	name: string,
	health: number,
	deck: { string },
	powerChance: number?,
	accuracyBonus: number?
): Combatant
	return {
		player = player,
		name = name,
		maxHealth = health,
		health = health,
		cycles = 0,
		powerChance = powerChance or 0,
		accuracyBonus = accuracyBonus or 0,
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

local function applySpell(battle: Battle, caster: Combatant, spell: SpellData.Spell, target: Combatant)
	-- Fizzle check (the W101 accuracy gamble); gear accuracy shifts the odds
	if rng:NextNumber(0, 100) > math.min(spell.accuracy + caster.accuracyBonus, 100) then
		table.insert(battle.lastEvents, ("%s cast %s — FIZZLED!"):format(caster.name, spell.name))
		return
	end

	local totalDamage, totalHeal, buffed = 0, 0, false
	for _, effect in spell.effects do
		if effect.kind == "Blade" then
			table.insert(caster.blades, { school = spell.school :: string, amount = effect.amount })
			buffed = true
		elseif effect.kind == "Trap" then
			table.insert(target.traps, { amount = effect.amount })
			buffed = true
		elseif effect.kind == "Shield" then
			table.insert(caster.shields, { amount = effect.amount })
			buffed = true
		elseif effect.kind == "Heal" then
			caster.health = math.min(caster.maxHealth, caster.health + effect.amount)
			totalHeal += effect.amount
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
				table.insert(
					battle.lastEvents,
					("%s cast %s — %d burn x%d rounds on %s"):format(
						caster.name,
						spell.name,
						dmg,
						effect.ticks or 3,
						target.name
					)
				)
			else
				target.health = math.max(0, target.health - dmg)
				totalDamage += dmg
			end
		end
	end
	if totalDamage > 0 then
		table.insert(
			battle.lastEvents,
			("%s cast %s — %d damage to %s"):format(caster.name, spell.name, totalDamage, target.name)
		)
	end
	if totalHeal > 0 then
		table.insert(battle.lastEvents, ("%s cast %s — healed %d"):format(caster.name, spell.name, totalHeal))
	end
	if buffed and totalDamage == 0 and totalHeal == 0 then
		table.insert(battle.lastEvents, ("%s cast %s"):format(caster.name, spell.name))
	end
end

-- Call once per round after all picks are in (or SELECT_TIME expires).
function CombatService.resolveRound(battle: Battle)
	battle.round += 1
	battle.lastEvents = {}

	-- DoT ticks first
	for _, c in battle.combatants do
		for i = #c.dots, 1, -1 do
			c.health = math.max(0, c.health - c.dots[i].amount)
			table.insert(battle.lastEvents, ("%s burns for %d"):format(c.name, c.dots[i].amount))
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

	-- Gain a cycle; powerChance rolls a double (W101 power pips)
	for _, c in battle.combatants do
		if c.health > 0 then
			if c.powerChance > 0 and rng:NextNumber() < c.powerChance then
				c.cycles += 2
				table.insert(battle.lastEvents, ("%s gains a POWER CYCLE"):format(c.name))
			else
				c.cycles += 1
			end
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
	local battle: Battle = { combatants = combatants, round = 0, active = true, lastEvents = {} }
	for _, c in combatants do
		c.cycles = 1 -- everyone starts with one cycle
	end
	return battle
end

CombatService.SELECT_TIME = SELECT_TIME
return CombatService
