--!strict
-- QuestData: the main quest line, in order. Linear chain like early Wizard City.

export type Quest = {
	id: string,
	title: string,
	enemy: string, -- EnemyData id to defeat
	count: number,
	xp: number,
	credits: number,
}

local list: { Quest } = {
	{
		id = "cr1",
		title = "Defeat Scrap Punks in Circuit Row",
		enemy = "scrap_punk",
		count = 3,
		xp = 150,
		credits = 75,
	},
	{ id = "cr2", title = "Defeat Wire Rats in Circuit Row", enemy = "wire_rat", count = 3, xp = 200, credits = 100 },
	{
		id = "sa1",
		title = "Defeat Chrome Gangers in Static Alley",
		enemy = "chrome_ganger",
		count = 4,
		xp = 350,
		credits = 150,
	},
	{
		id = "sa2",
		title = "Defeat Data Wraiths in Static Alley",
		enemy = "data_wraith",
		count = 3,
		xp = 500,
		credits = 225,
	},
	{
		id = "cs1",
		title = "Defeat Sentinels on the Chrome Strip",
		enemy = "sentinel_unit",
		count = 3,
		xp = 700,
		credits = 300,
	},
	{ id = "cs2", title = "Flatline THE GLITCH KING", enemy = "glitch_king", count = 1, xp = 1500, credits = 1000 },
}

return { list = list }
