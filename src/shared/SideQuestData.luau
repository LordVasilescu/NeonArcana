--!strict
-- SideQuestData: optional street quests handed out by Fixers at each street mouth.

export type SideQuest = {
	id: string,
	zone: string,
	title: string,
	enemy: string,
	count: number,
	xp: number,
	credits: number,
}

local list: { SideQuest } = {
	{
		id = "scr1",
		zone = "circuit_row",
		title = "Thin out the Scrap Punks",
		enemy = "scrap_punk",
		count = 5,
		xp = 120,
		credits = 60,
	},
	{
		id = "scr2",
		zone = "circuit_row",
		title = "Rat problem on the Row",
		enemy = "wire_rat",
		count = 5,
		xp = 160,
		credits = 80,
	},
	{
		id = "ssa1",
		zone = "static_alley",
		title = "Gangers shaking down shops",
		enemy = "chrome_ganger",
		count = 5,
		xp = 260,
		credits = 120,
	},
	{
		id = "ssa2",
		zone = "static_alley",
		title = "Wraiths in the wires",
		enemy = "data_wraith",
		count = 4,
		xp = 380,
		credits = 170,
	},
	{
		id = "scs1",
		zone = "chrome_strip",
		title = "Sentinel patrol sweep",
		enemy = "sentinel_unit",
		count = 4,
		xp = 520,
		credits = 240,
	},
	{
		id = "smb1",
		zone = "mainframe_blvd",
		title = "Knights guarding the core",
		enemy = "proxy_knight",
		count = 4,
		xp = 700,
		credits = 320,
	},
	{
		id = "smb2",
		zone = "mainframe_blvd",
		title = "Stalkers in the dark",
		enemy = "grid_stalker",
		count = 4,
		xp = 900,
		credits = 420,
	},
}

local byZone: { [string]: { SideQuest } } = {}
for _, quest in list do
	byZone[quest.zone] = byZone[quest.zone] or {}
	table.insert(byZone[quest.zone], quest)
end

local byId: { [string]: SideQuest } = {}
for _, quest in list do
	byId[quest.id] = quest
end

return { list = list, byZone = byZone, byId = byId }
