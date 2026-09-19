--!nonstrict
-- Data integrity: every cross-reference between the shared data tables resolves.
-- Catches typos in enemy decks, drop tables, quest targets, and zone pads before Studio.

local T = require("./harness")
local SpellData = T.shared("SpellData")
local EnemyData = T.shared("EnemyData")
local GearData = T.shared("GearData")
local QuestData = T.shared("QuestData")
local SideQuestData = T.shared("SideQuestData")
local ZoneData = T.shared("ZoneData")

local SCHOOLS =
	{ Burnout = true, Coolant = true, Surge = true, Patch = true, Leech = true, Ghost = true, Kernel = true }
local EFFECT_KINDS = { Damage = true, Heal = true, Blade = true, Trap = true, Shield = true, DoT = true }
local SLOTS = { visor = true, jacket = true, boots = true }

-- Spells
local spellCount = 0
local level1Attack = {}
for id, spell in SpellData do
	spellCount += 1
	T.check("spell id matches key: " .. id, spell.id == id)
	T.check("spell school valid: " .. id, SCHOOLS[spell.school] == true, spell.school)
	T.check("spell cost 0..3: " .. id, spell.cost >= 0 and spell.cost <= 3, spell.cost)
	T.check("spell accuracy 1..100: " .. id, spell.accuracy > 0 and spell.accuracy <= 100, spell.accuracy)
	T.check("spell has effects: " .. id, #spell.effects > 0)
	for _, e in spell.effects do
		T.check("effect kind valid: " .. id, EFFECT_KINDS[e.kind] == true, e.kind)
		T.check("effect amount positive: " .. id, e.amount > 0, e.amount)
		if e.kind == "DoT" then
			T.check("DoT has ticks: " .. id, typeof(e.ticks) == "number" and e.ticks > 0)
		end
		if e.kind == "Damage" and spell.levelReq <= 1 then
			level1Attack[spell.school] = true
		end
	end
end
T.check("spell table non-empty", spellCount > 0, spellCount)
for school in SCHOOLS do
	T.check("school has a level-1 attack: " .. school, level1Attack[school] == true)
end

-- Gear
for id, item in GearData do
	T.check("gear id matches key: " .. id, item.id == id)
	T.check("gear slot valid: " .. id, SLOTS[item.slot] == true, item.slot)
	T.check("gear tier positive: " .. id, item.tier >= 1)
end

-- Enemies
for id, enemy in EnemyData do
	T.check("enemy id matches key: " .. id, enemy.id == id)
	T.check("enemy school valid: " .. id, SCHOOLS[enemy.school] == true, enemy.school)
	T.check("enemy has a deck: " .. id, #enemy.deck > 0)
	local hasAttack = false
	for _, spellId in enemy.deck do
		T.check(("enemy %s deck card exists: %s"):format(id, spellId), SpellData[spellId] ~= nil)
		local spell = SpellData[spellId]
		if spell then
			for _, e in spell.effects do
				if e.kind == "Damage" or e.kind == "DoT" then
					hasAttack = true
				end
			end
		end
	end
	T.check("enemy can actually deal damage: " .. id, hasAttack)
	for _, drop in enemy.drops or {} do
		T.check(("enemy %s drop gear exists: %s"):format(id, drop.gear), GearData[drop.gear] ~= nil)
		T.check(("enemy %s drop chance 0..1: %s"):format(id, drop.gear), drop.chance > 0 and drop.chance <= 1)
	end
end

-- Main quest chain
local seenQuestIds = {}
for i, quest in QuestData.list do
	T.check("quest enemy exists: " .. quest.id, EnemyData[quest.enemy] ~= nil, quest.enemy)
	T.check("quest id unique: " .. quest.id, not seenQuestIds[quest.id])
	seenQuestIds[quest.id] = true
	T.check("quest count positive: " .. quest.id, quest.count >= 1)
	if i > 1 then
		local prev = QuestData.list[i - 1]
		local prevLv = EnemyData[prev.enemy] and EnemyData[prev.enemy].level or 0
		local lv = EnemyData[quest.enemy] and EnemyData[quest.enemy].level or 0
		T.check("quest chain never drops enemy level: " .. quest.id, lv >= prevLv, ("%d -> %d"):format(prevLv, lv))
	end
end

-- Side quests
local zoneIds = {}
for _, zone in ZoneData.list do
	zoneIds[zone.id] = true
end
for _, sq in SideQuestData.list do
	T.check("side quest enemy exists: " .. sq.id, EnemyData[sq.enemy] ~= nil, sq.enemy)
	T.check("side quest zone exists: " .. sq.id, zoneIds[sq.zone] == true, sq.zone)
	T.check("side quest indexed by id: " .. sq.id, SideQuestData.byId[sq.id] == sq)
end

-- Zones: one linear road. Every segment heads +X and starts exactly where the previous
-- one ends, so the objective path is a straight walk.
for i, zone in ZoneData.list do
	T.check("zone heads +X: " .. zone.id, zone.dir.X == 1 and zone.dir.Y == 0 and zone.dir.Z == 0)
	local start = zone.startOverride or ZoneData.ROAD_START
	local expected = ZoneData.ROAD_START + ZoneData.ROAD_LENGTH * (i - 1)
	T.check("zone segment is contiguous: " .. zone.id, start == expected, ("%d vs %d"):format(start, expected))
end
for _, zone in ZoneData.list do
	T.check("zone has pads: " .. zone.id, #zone.pads > 0)
	T.check("zone dir is unit length: " .. zone.id, math.abs(zone.dir.Magnitude - 1) < 1e-6, zone.dir.Magnitude)
	for _, pad in zone.pads do
		T.check(("zone %s pad enemy exists: %s"):format(zone.id, pad.enemy), EnemyData[pad.enemy] ~= nil)
		T.check(("zone %s pad position in 0..1"):format(zone.id), pad.at >= 0 and pad.at <= 1, pad.at)
	end
	T.check("zone indexed by id: " .. zone.id, ZoneData.byId[zone.id] == zone)
end

return T
