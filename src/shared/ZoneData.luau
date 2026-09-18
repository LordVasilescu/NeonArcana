--!strict
-- ZoneData: streets radiating from the Neon Plaza hub, W101 Wizard City layout.
-- crownCost > 0 = premium street (the classic zone-gate monetization).

export type Pad = { enemy: string, at: number } -- at = fraction along the road

export type Zone = {
	id: string,
	name: string,
	levelText: string,
	crownCost: number,
	dir: Vector3, -- unit direction from hub center
	pads: { Pad },
	startOverride: number?, -- road start distance; default ROAD_START (lets zones chain outward)
}

local ROAD_START = 40 -- studs from hub center to road entrance
local ROAD_LENGTH = 140
local ROAD_WIDTH = 24

local list: { Zone } = {
	{
		id = "circuit_row",
		name = "Circuit Row",
		levelText = "Lv 1-4",
		crownCost = 0,
		dir = Vector3.new(1, 0, 0),
		pads = {
			{ enemy = "scrap_punk", at = 0.2 },
			{ enemy = "scrap_punk", at = 0.45 },
			{ enemy = "wire_rat", at = 0.7 },
			{ enemy = "wire_rat", at = 0.95 },
		},
	},
	{
		id = "static_alley",
		name = "Static Alley",
		levelText = "Lv 4-8",
		crownCost = 0,
		dir = Vector3.new(-1, 0, 0),
		pads = {
			{ enemy = "chrome_ganger", at = 0.2 },
			{ enemy = "chrome_ganger", at = 0.45 },
			{ enemy = "data_wraith", at = 0.7 },
			{ enemy = "data_wraith", at = 0.95 },
		},
	},
	{
		id = "chrome_strip",
		name = "Chrome Strip",
		levelText = "Lv 8-12",
		crownCost = 0, -- was premium; Wizard City stays free, choom
		dir = Vector3.new(0, 0, -1),
		pads = {
			{ enemy = "sentinel_unit", at = 0.25 },
			{ enemy = "sentinel_unit", at = 0.5 },
			{ enemy = "glitch_king", at = 0.9 },
		},
	},
	-- District 5: chained beyond the Chrome Strip — walk it to the end and descend.
	{
		id = "undergrid",
		name = "The Undergrid",
		levelText = "Lv 18-25",
		crownCost = 1250,
		dir = Vector3.new(0, 0, -1),
		startOverride = 200, -- begins where Chrome Strip ends
		pads = {
			{ enemy = "grid_stalker", at = 0.3 }, -- placeholder roster until Undergrid enemies land
			{ enemy = "grid_stalker", at = 0.6 },
			{ enemy = "overseer_prime", at = 0.92 },
		},
	},
	-- The Colossus Boulevard move: one late premium street once you're hooked.
	{
		id = "mainframe_blvd",
		name = "Mainframe Boulevard",
		levelText = "Lv 12-18",
		crownCost = 750,
		dir = Vector3.new(0, 0, 1),
		pads = {
			{ enemy = "proxy_knight", at = 0.2 },
			{ enemy = "proxy_knight", at = 0.4 },
			{ enemy = "grid_stalker", at = 0.6 },
			{ enemy = "grid_stalker", at = 0.78 },
			{ enemy = "overseer_prime", at = 0.95 },
		},
	},
}

local byId: { [string]: Zone } = {}
for _, zone in list do
	byId[zone.id] = zone
end

return {
	list = list,
	byId = byId,
	ROAD_START = ROAD_START,
	ROAD_LENGTH = ROAD_LENGTH,
	ROAD_WIDTH = ROAD_WIDTH,
}
