--!nonstrict
-- CombatService unit tests: deterministic checks on the pure combat math.

local T = require("./harness")
local CombatService = require("../../src/server/CombatService")

local function fresh(heroDeck: { string }, dummyDeck: { string }?)
	local hero = CombatService.newCombatant(nil, "Hero", 500, heroDeck)
	local dummy = CombatService.newCombatant(nil, "Dummy", 10000, dummyDeck or { "firewall" })
	local battle = CombatService.newBattle({ hero, dummy })
	return battle, hero, dummy
end

-- give a combatant enough cycles to cast anything
local function fund(c, n)
	c.cycles = n or 10
end

-- cast until it lands (accuracy < 100 fizzles are random); returns rounds used
local function castUntilHit(battle, casterIndex, spellId, targetIndex, target)
	local before = target.health
	for i = 1, 200 do
		fund(battle.combatants[casterIndex])
		T.check("cast accepted: " .. spellId, CombatService.requestCast(battle, casterIndex, spellId, targetIndex))
		CombatService.resolveRound(battle)
		if target.health < before then
			return i
		end
	end
	return nil
end

do -- battle setup
	local battle, hero = fresh({ "overclock", "ember_jab" })
	T.check("new battle is active", battle.active)
	T.check("round starts at 0", battle.round == 0)
	T.check("combatants start with 1 cycle", hero.cycles == 1)
end

do -- requestCast validation
	local battle, hero = fresh({ "ember_jab" })
	T.check("rejects card not in deck", not CombatService.requestCast(battle, 1, "meltdown", 2))
	T.check("rejects unknown spell id", not CombatService.requestCast(battle, 1, "not_a_spell", 2))
	T.check("rejects bad target index", not CombatService.requestCast(battle, 1, "ember_jab", 99))
	hero.cycles = 0
	T.check("rejects unaffordable cost", not CombatService.requestCast(battle, 1, "ember_jab", 2))
	hero.cycles = 1
	T.check("accepts affordable card in deck", CombatService.requestCast(battle, 1, "ember_jab", 2))
	battle.active = false
	T.check("rejects when battle over", not CombatService.requestCast(battle, 1, "ember_jab", 2))
end

do -- cycle economy
	local battle, hero = fresh({ "ember_jab" })
	fund(hero, 3)
	CombatService.requestCast(battle, 1, "ember_jab", 2)
	CombatService.resolveRound(battle)
	T.check("cost deducted then +1 cycle per round", hero.cycles == 3 - 1 + 1, hero.cycles)
	CombatService.resolveRound(battle)
	T.check("idle round still gains a cycle", hero.cycles == 4, hero.cycles)
	T.check("pending cast cleared after resolve", hero.pendingCast == nil)
end

do -- blade math (100% accuracy blade, then a hit)
	local battle, hero, dummy = fresh({ "overclock", "ember_jab" })
	CombatService.requestCast(battle, 1, "overclock", 1)
	CombatService.resolveRound(battle)
	T.check("blade stored", #hero.blades == 1)
	castUntilHit(battle, 1, "ember_jab", 2, dummy)
	T.check("bladed hit = floor(70 * 1.35) = 94", 10000 - dummy.health == 94, 10000 - dummy.health)
	T.check("blade consumed on hit", #hero.blades == 0)
end

do -- off-school blade is NOT consumed by a different school hit
	local battle, hero, dummy = fresh({ "surge_blade", "ember_jab" })
	CombatService.requestCast(battle, 1, "surge_blade", 1)
	CombatService.resolveRound(battle)
	castUntilHit(battle, 1, "ember_jab", 2, dummy)
	T.check("off-school hit deals base 70", 10000 - dummy.health == 70, 10000 - dummy.health)
	T.check("off-school blade survives", #hero.blades == 1)
end

do -- trap on target multiplies, shield on target reduces, both consumed
	local battle, _hero, dummy = fresh({ "backdraft", "ember_jab" }, { "firewall" })
	-- hero traps dummy (+30%), dummy shields itself (-70%)
	CombatService.requestCast(battle, 1, "backdraft", 2)
	fund(dummy)
	CombatService.requestCast(battle, 2, "firewall", 2)
	CombatService.resolveRound(battle)
	T.check("trap placed on target", #dummy.traps == 1)
	T.check("shield placed on target", #dummy.shields == 1)
	castUntilHit(battle, 1, "ember_jab", 2, dummy)
	-- 70 * 1.3 * 0.3 = 27.3 -> 27
	T.check("trap+shield hit = floor(70*1.3*0.3) = 27", 10000 - dummy.health == 27, 10000 - dummy.health)
	T.check("trap consumed", #dummy.traps == 0)
	T.check("shield consumed", #dummy.shields == 0)
end

do -- DoT ticks each round then expires
	local battle, hero, dummy = fresh({ "thermal_bleed" })
	local landed = false
	for _ = 1, 200 do
		fund(hero)
		CombatService.requestCast(battle, 1, "thermal_bleed", 2)
		CombatService.resolveRound(battle)
		if #dummy.dots > 0 then
			landed = true
			break
		end
	end
	T.check("DoT applied", landed)
	local hp = dummy.health
	CombatService.resolveRound(battle)
	T.check("DoT ticks 55", hp - dummy.health == 55, hp - dummy.health)
	CombatService.resolveRound(battle)
	CombatService.resolveRound(battle)
	T.check("DoT expires after 3 ticks", #dummy.dots == 0, #dummy.dots)
	local hp2 = dummy.health
	CombatService.resolveRound(battle)
	T.check("no damage after expiry", dummy.health == hp2)
end

do -- heal caps at max health and applies to caster
	local battle, hero = fresh({ "hotfix" })
	hero.health = 450
	local healed = false
	for _ = 1, 200 do
		fund(hero)
		CombatService.requestCast(battle, 1, "hotfix", 2)
		CombatService.resolveRound(battle)
		if hero.health > 450 then
			healed = true
			break
		end
	end
	T.check("heal landed", healed)
	T.check("heal capped at maxHealth", hero.health == 500, hero.health)
end

do -- kill ends the battle and clamps at 0
	local battle, hero, dummy = fresh({ "ember_jab" })
	dummy.health = 1
	for _ = 1, 200 do
		fund(hero)
		CombatService.requestCast(battle, 1, "ember_jab", 2)
		CombatService.resolveRound(battle)
		if not battle.active then
			break
		end
	end
	T.check("battle inactive after kill", not battle.active)
	T.check("health clamps at 0", dummy.health == 0)
end

do -- dead caster's pending cast is skipped and it gains no cycles
	local battle, hero, dummy = fresh({ "ember_jab" })
	fund(hero)
	CombatService.requestCast(battle, 1, "ember_jab", 2)
	hero.health = 0
	local before = dummy.health
	CombatService.resolveRound(battle)
	T.check("dead caster deals no damage", dummy.health == before)
	T.check("dead caster gains no cycles", hero.cycles == 10, hero.cycles)
end

return T
