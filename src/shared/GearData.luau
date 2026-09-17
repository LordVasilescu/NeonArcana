--!strict
-- GearData: equipment. Three slots (visor/jacket/boots), stat bonuses, W101-style
-- enemy drops. Drop tables live on EnemyData entries.

export type Gear = {
	id: string,
	name: string,
	slot: "visor" | "jacket" | "boots",
	health: number, -- bonus max HP in battle
	accuracy: number, -- bonus % added to every card's accuracy
	power: number, -- bonus power-cycle chance (0.01 = +1%)
	tier: number, -- for "is this an upgrade" comparisons
}

local Gear: { [string]: Gear } = {}

local function gear(id: string, name: string, slot: any, tier: number, health: number, accuracy: number, power: number)
	Gear[id] = { id = id, name = name, slot = slot, tier = tier, health = health, accuracy = accuracy, power = power }
end

-- Tier 1: Circuit Row drops
gear("scrap_visor", "Scrap Visor", "visor", 1, 20, 0, 0)
gear("punk_jacket", "Punk Jacket", "jacket", 1, 30, 0, 0)
gear("wire_boots", "Wire Boots", "boots", 1, 0, 0, 0.02)

-- Tier 2: Static Alley drops
gear("chrome_visor", "Chrome Visor", "visor", 2, 40, 2, 0)
gear("ganger_plate", "Ganger Plate", "jacket", 2, 60, 0, 0)
gear("wraith_striders", "Wraith Striders", "boots", 2, 20, 0, 0.03)

-- Tier 3: Chrome Strip drops
gear("sentinel_helm", "Sentinel Helm", "visor", 3, 70, 3, 0)
gear("glitch_crown", "Glitch Crown", "visor", 4, 100, 5, 0.03) -- Glitch King only

-- Tier 4: Mainframe Boulevard drops
gear("knight_plate", "Knight Plate", "jacket", 4, 120, 0, 0)
gear("stalker_treads", "Stalker Treads", "boots", 4, 40, 0, 0.05)
gear("overseer_halo", "Overseer Halo", "visor", 5, 150, 5, 0.05) -- Overseer Prime only

return Gear
