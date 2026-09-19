--!strict
-- ZoneData: ONE linear street, Wizard101-style. Every district is the next segment of
-- the same road heading +X from the plaza, so the path to the objective is never in
-- doubt: walk forward, fight the pads in order, reach the gate, reach the boss.
-- crownCost > 0 = premium segment (a gate blocks the road until unlocked).

export type Pad = { enemy: string, at: number } -- at = fraction along the segment

export type Zone = {
	id: string,
	name: string,
	levelText: string,
	crownCost: number,
	dir: Vector3, -- unit direction of the road (all segments share +X)
	pads: { Pad },
	startOverride: number?, -- distance from the plaza where this segment begins
}

local ROAD_START = 40 -- studs from plaza centre to the first segment
local ROAD_LENGTH = 140 -- per segment
local ROAD_WIDTH = 24

local EAST = Vector3.new(1, 0, 0)

local list: { Zone } = {
	{
		id = "circuit_row",
		name = "Circuit Row",
		levelText = "Lv 1-4",
		crownCost = 0,
		dir = EAST,
		startOverride = ROAD_START,
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
		dir = EAST,
		startOverride = ROAD_START + ROAD_LENGTH,
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
		crownCost = 0, -- Wizard City stays free, choom
		dir = EAST,
		startOverride = ROAD_START + ROAD_LENGTH * 2,
		pads = {
			{ enemy = "sentinel_unit", at = 0.25 },
			{ enemy = "sentinel_unit", at = 0.5 },
			{ enemy = "glitch_king", at = 0.9 },
		},
	},
	-- The Colossus Boulevard move: one late premium segment once you're hooked.
	{
		id = "mainframe_blvd",
		name = "Mainframe Boulevard",
		levelText = "Lv 12-18",
		crownCost = 750,
		dir = EAST,
		startOverride = ROAD_START + ROAD_LENGTH * 3,
		pads = {
			{ enemy = "proxy_knight", at = 0.2 },
			{ enemy = "proxy_knight", at = 0.4 },
			{ enemy = "grid_stalker", at = 0.6 },
			{ enemy = "grid_stalker", at = 0.78 },
			{ enemy = "overseer_prime", at = 0.95 },
		},
	},
	-- District 5: the end of the road.
	{
		id = "undergrid",
		name = "The Undergrid",
		levelText = "Lv 18-25",
		crownCost = 1250,
		dir = EAST,
		startOverride = ROAD_START + ROAD_LENGTH * 4,
		pads = {
			{ enemy = "grid_stalker", at = 0.3 }, -- placeholder roster until Undergrid enemies land
			{ enemy = "grid_stalker", at = 0.6 },
			{ enemy = "overseer_prime", at = 0.92 },
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
