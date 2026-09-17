--!strict
-- EnemyData: the mob roster. Deck ids must exist in SpellData.

export type Enemy = {
	id: string,
	name: string,
	school: string,
	level: number,
	health: number,
	deck: { string },
	xp: number,
	credits: number,
	boss: boolean?,
}

local Enemies: { [string]: Enemy } = {
	scrap_punk = {
		id = "scrap_punk",
		name = "Scrap Punk",
		school = "Burnout",
		level = 2,
		health = 250,
		deck = { "ember_jab", "overclock" },
		xp = 40,
		credits = 15,
	},
	wire_rat = {
		id = "wire_rat",
		name = "Wire Rat",
		school = "Surge",
		level = 3,
		health = 280,
		deck = { "static_shock", "surge_blade" },
		xp = 55,
		credits = 20,
	},
	chrome_ganger = {
		id = "chrome_ganger",
		name = "Chrome Ganger",
		school = "Coolant",
		level = 5,
		health = 420,
		deck = { "frost_packet", "firewall", "cryo_spike" },
		xp = 80,
		credits = 35,
	},
	data_wraith = {
		id = "data_wraith",
		name = "Data Wraith",
		school = "Leech",
		level = 7,
		health = 550,
		deck = { "siphon", "data_drain", "corrupt_blade" },
		xp = 110,
		credits = 50,
	},
	sentinel_unit = {
		id = "sentinel_unit",
		name = "Sentinel Unit",
		school = "Coolant",
		level = 9,
		health = 720,
		deck = { "cryo_spike", "firewall", "glacier_crash" },
		xp = 150,
		credits = 70,
	},
	glitch_king = {
		id = "glitch_king",
		name = "THE GLITCH KING",
		school = "Ghost",
		level = 12,
		health = 1400,
		deck = { "specter_bolt", "hologram_strike", "ghost_blade", "poltergeist" },
		xp = 600,
		credits = 400,
		boss = true,
	},
}

return Enemies
