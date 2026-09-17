--!strict
-- SpellData: card definitions. Shared so client can render cards and server can validate.
-- Server is ALWAYS the authority on what a card actually does.

export type SpellEffect = {
	kind: "Damage" | "Heal" | "Blade" | "Trap" | "Shield" | "DoT",
	amount: number, -- damage/heal value, or percent for blade/trap/shield
	ticks: number?, -- for DoT: number of rounds
}

export type Spell = {
	id: string,
	name: string,
	school: "Burnout" | "Coolant" | "Surge" | "Patch" | "Leech" | "Ghost" | "Kernel",
	cost: number, -- cycles (pips)
	accuracy: number, -- 0-100
	effects: { SpellEffect },
	description: string,
}

local Spells: { [string]: Spell } = {
	-- BURNOUT (fire): DoT school
	spark_jab = {
		id = "spark_jab",
		name = "Spark Jab",
		school = "Burnout",
		cost = 1,
		accuracy = 85,
		effects = { { kind = "Damage", amount = 80 } },
		description = "A quick jolt of overclocked current.",
	},
	thermal_bleed = {
		id = "thermal_bleed",
		name = "Thermal Bleed",
		school = "Burnout",
		cost = 2,
		accuracy = 80,
		effects = { { kind = "DoT", amount = 60, ticks = 3 } },
		description = "Cook their heatsinks over 3 rounds.",
	},
	overclock_blade = {
		id = "overclock_blade",
		name = "Overclock",
		school = "Burnout",
		cost = 0,
		accuracy = 100,
		effects = { { kind = "Blade", amount = 35 } },
		description = "+35% to your next Burnout hit.",
	},

	-- COOLANT (ice): tank school
	frost_packet = {
		id = "frost_packet",
		name = "Frost Packet",
		school = "Coolant",
		cost = 1,
		accuracy = 90,
		effects = { { kind = "Damage", amount = 65 } },
		description = "A compressed packet of liquid-nitro code.",
	},
	firewall = {
		id = "firewall",
		name = "Firewall",
		school = "Coolant",
		cost = 0,
		accuracy = 100,
		effects = { { kind = "Shield", amount = 70 } },
		description = "-70% from the next incoming hit.",
	},

	-- PATCH (life): heal school
	hotfix = {
		id = "hotfix",
		name = "Hotfix",
		school = "Patch",
		cost = 1,
		accuracy = 95,
		effects = { { kind = "Heal", amount = 120 } },
		description = "Emergency repair subroutine.",
	},
	exploit_trap = {
		id = "exploit_trap",
		name = "Exploit",
		school = "Patch",
		cost = 0,
		accuracy = 100,
		effects = { { kind = "Trap", amount = 30 } },
		description = "+30% to the next hit on this target.",
	},
}

return Spells
