--!nonstrict
-- PlayerDataService: profiles (level/xp/credits/school/quests/zones), DataStore-backed
-- with in-memory fallback for offline Studio. Also handles quest progression and the
-- SelectSchool / UnlockZone remotes.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpellData = require(ReplicatedStorage.Shared.SpellData)
local QuestData = require(ReplicatedStorage.Shared.QuestData)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local GearData = require(ReplicatedStorage.Shared.GearData)
local SideQuestData = require(ReplicatedStorage.Shared.SideQuestData)
local CrownService = require(script.Parent.CrownService)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local hudUpdate = remotes:WaitForChild("HUDUpdate")
local notify = remotes:WaitForChild("Notify")
local selectSchool = remotes:WaitForChild("SelectSchool")
local unlockZone = remotes:WaitForChild("UnlockZone")
local deckUpdate = remotes:WaitForChild("DeckUpdate")

local MAX_DECK = 7
local MIN_DECK = 3

local SCHOOLS = { "Burnout", "Coolant", "Surge", "Patch", "Leech", "Ghost", "Kernel" }
local STUDIO_STARTER_CROWNS = 2500 -- test wallet so the crown gate is exercisable offline

local ok, store = pcall(function()
	return DataStoreService:GetDataStore("PlayerData_v1")
end)
if not ok then
	store = nil
	warn("[PlayerData] DataStores unavailable (offline Studio?) — profiles are in-memory")
end

local PlayerDataService = {}
local profiles = {}

local function defaultProfile()
	return {
		school = nil,
		level = 1,
		xp = 0,
		credits = 0,
		questIndex = 1,
		questKills = 0,
		zones = { circuit_row = true, static_alley = true, chrome_strip = true }, -- mainframe_blvd is premium
		gear = {}, -- slot -> gearId
		inventory = {}, -- unequipped gearIds
		sideQuests = {}, -- questId -> { kills = n, done = bool }
	}
end

local function xpNeeded(level: number): number
	return math.floor(100 * level ^ 1.5)
end

function PlayerDataService.get(player)
	return profiles[player]
end

function PlayerDataService.pushHUD(player)
	local p = profiles[player]
	if not p then
		return
	end
	local quest = QuestData.list[p.questIndex]
	local questText = quest and ("%s (%d/%d)"):format(quest.title, p.questKills, quest.count)
		or "All quests complete — more districts soon!"
	for questId, state in p.sideQuests or {} do
		local sideQuest = SideQuestData.byId[questId]
		if sideQuest and not state.done then
			questText ..= ("\n[side] %s (%d/%d)"):format(sideQuest.title, state.kills, sideQuest.count)
			break -- one side line keeps the HUD readable
		end
	end
	hudUpdate:FireClient(player, {
		level = p.level,
		xp = p.xp,
		xpNeeded = xpNeeded(p.level),
		credits = p.credits,
		crowns = CrownService.getBalance(player),
		school = p.school,
		questText = questText,
		ownedCards = PlayerDataService.getOwnedCards(player),
		deck = PlayerDataService.getDeck(player),
	})
end

function PlayerDataService.notify(player, text: string, offer)
	notify:FireClient(player, { text = text, offer = offer })
end

function PlayerDataService.addXP(player, amount: number)
	local p = profiles[player]
	if not p then
		return
	end
	p.xp += amount
	while p.xp >= xpNeeded(p.level) do
		p.xp -= xpNeeded(p.level)
		p.level += 1
		PlayerDataService.notify(player, ("LEVEL UP! You are now level %d"):format(p.level))
	end
end

function PlayerDataService.addCredits(player, amount: number)
	local p = profiles[player]
	if p then
		p.credits += amount
	end
end

-- Accept the next open side quest for a zone (called by Fixer NPCs).
function PlayerDataService.acceptSideQuest(player, zoneId: string)
	local p = profiles[player]
	if not p then
		return
	end
	p.sideQuests = p.sideQuests or {}
	for _, quest in SideQuestData.byZone[zoneId] or {} do
		local state = p.sideQuests[quest.id]
		if not state then
			p.sideQuests[quest.id] = { kills = 0, done = false }
			PlayerDataService.notify(player, ("SIDE JOB: %s (%d %s)"):format(quest.title, quest.count, quest.enemy))
			PlayerDataService.pushHUD(player)
			return
		elseif not state.done then
			PlayerDataService.notify(
				player,
				("Still working: %s (%d/%d)"):format(quest.title, state.kills, quest.count)
			)
			return
		end
	end
	PlayerDataService.notify(player, "No more side jobs here. Check another street.")
end

-- Called by BattleRunner on every win. Advances the main chain + active side quests.
function PlayerDataService.recordKill(player, enemyId: string)
	local p = profiles[player]
	if not p then
		return
	end
	local quest = QuestData.list[p.questIndex]
	if quest and quest.enemy == enemyId then
		p.questKills += 1
		if p.questKills >= quest.count then
			p.questIndex += 1
			p.questKills = 0
			PlayerDataService.addXP(player, quest.xp)
			p.credits += quest.credits
			PlayerDataService.notify(player, ("QUEST COMPLETE! +%d XP, +%d credits"):format(quest.xp, quest.credits))
		end
	end
	for questId, state in p.sideQuests or {} do
		local sideQuest = SideQuestData.byId[questId]
		if sideQuest and not state.done and sideQuest.enemy == enemyId then
			state.kills += 1
			if state.kills >= sideQuest.count then
				state.done = true
				PlayerDataService.addXP(player, sideQuest.xp)
				p.credits += sideQuest.credits
				PlayerDataService.notify(
					player,
					("SIDE JOB DONE: %s! +%d XP, +%d credits"):format(sideQuest.title, sideQuest.xp, sideQuest.credits)
				)
			end
		end
	end
	PlayerDataService.pushHUD(player)
end

function PlayerDataService.isZoneUnlocked(player, zoneId: string): boolean
	local p = profiles[player]
	return p ~= nil and p.zones[zoneId] == true
end

-- Sum of stat bonuses from equipped gear.
function PlayerDataService.getGearStats(player): (number, number, number)
	local p = profiles[player]
	local health, accuracy, power = 0, 0, 0
	if p and p.gear then
		for _, gearId in p.gear do
			local item = GearData[gearId]
			if item then
				health += item.health
				accuracy += item.accuracy
				power += item.power
			end
		end
	end
	return health, accuracy, power
end

-- Award a drop. Auto-equips if the slot is empty or the new piece is a higher tier.
function PlayerDataService.awardGear(player, gearId: string)
	local p = profiles[player]
	local item = GearData[gearId]
	if not p or not item then
		return
	end
	p.gear = p.gear or {}
	p.inventory = p.inventory or {}
	local equipped = GearData[p.gear[item.slot] or ""]
	if not equipped or item.tier > equipped.tier then
		if equipped then
			table.insert(p.inventory, equipped.id)
		end
		p.gear[item.slot] = gearId
		PlayerDataService.notify(
			player,
			("LOOT: %s equipped! (+%dHP +%d%%acc +%d%%pow)"):format(
				item.name,
				item.health,
				item.accuracy,
				math.floor(item.power * 100)
			)
		)
	else
		table.insert(p.inventory, gearId)
		PlayerDataService.notify(player, ("LOOT: %s (stashed — you have better)"):format(item.name))
	end
end

-- Every card this profile owns: school spells at or below level.
local function ownedCards(p): { string }
	local school = (p and p.school) or "Burnout"
	local level = (p and p.level) or 1
	local owned = {}
	for id, spell in SpellData do
		if spell.school == school and spell.levelReq <= level then
			table.insert(owned, id)
		end
	end
	return owned
end

local function sortByCost(deck: { string })
	table.sort(deck, function(a, b)
		local sa, sb = SpellData[a], SpellData[b]
		if sa.cost ~= sb.cost then
			return sa.cost < sb.cost
		end
		return sa.name < sb.name
	end)
end

function PlayerDataService.getOwnedCards(player): { string }
	local owned = ownedCards(profiles[player])
	sortByCost(owned)
	return owned
end

-- Battle deck: the player's custom deck if valid, else everything owned.
function PlayerDataService.getDeck(player): { string }
	local p = profiles[player]
	local owned = ownedCards(p)
	local deck = owned
	if p and typeof(p.customDeck) == "table" then
		local ownedSet = {}
		for _, id in owned do
			ownedSet[id] = true
		end
		local filtered = {}
		for _, id in p.customDeck do
			if ownedSet[id] and not table.find(filtered, id) then
				table.insert(filtered, id)
			end
		end
		if #filtered >= MIN_DECK then
			deck = filtered
		end
	end
	sortByCost(deck)
	return deck
end

local function loadProfile(player)
	local saved = nil
	if store then
		local loaded, result = pcall(function()
			return store:GetAsync(tostring(player.UserId))
		end)
		if loaded then
			saved = result
		end
	end
	local profile = defaultProfile()
	if typeof(saved) == "table" then
		for key, value in saved do
			profile[key] = value
		end
	end
	profiles[player] = profile
end

local function saveProfile(player)
	local p = profiles[player]
	if not p or not store then
		return
	end
	pcall(function()
		store:SetAsync(tostring(player.UserId), p)
	end)
end

function PlayerDataService.init()
	selectSchool.OnServerEvent:Connect(function(player, school)
		local p = profiles[player]
		if p and not p.school and table.find(SCHOOLS, school) then
			p.school = school
			PlayerDataService.notify(player, ("Welcome, %s Codeslinger. Circuit Row needs you."):format(school))
			PlayerDataService.pushHUD(player)
		end
	end)

	deckUpdate.OnServerEvent:Connect(function(player, list)
		local p = profiles[player]
		if not p or typeof(list) ~= "table" or #list > MAX_DECK then
			return
		end
		local ownedSet = {}
		for _, id in ownedCards(p) do
			ownedSet[id] = true
		end
		local clean = {}
		for _, id in list do
			if typeof(id) == "string" and ownedSet[id] and not table.find(clean, id) then
				table.insert(clean, id)
			end
		end
		if #clean < MIN_DECK then
			PlayerDataService.notify(player, ("Deck needs at least %d cards."):format(MIN_DECK))
			return
		end
		p.customDeck = clean
		PlayerDataService.notify(player, ("Deck saved: %d cards loaded."):format(#clean))
		PlayerDataService.pushHUD(player)
	end)

	unlockZone.OnServerEvent:Connect(function(player, zoneId)
		local zone = typeof(zoneId) == "string" and ZoneData.byId[zoneId]
		local p = profiles[player]
		if not zone or not p or p.zones[zoneId] or zone.crownCost <= 0 then
			return
		end
		if CrownService.trySpend(player, zone.crownCost) then
			p.zones[zoneId] = true
			saveProfile(player)
			PlayerDataService.notify(player, ("%s UNLOCKED! Get in there."):format(zone.name))
		else
			PlayerDataService.notify(player, ("Not enough Crowns (need %d)."):format(zone.crownCost))
		end
		PlayerDataService.pushHUD(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		loadProfile(player)
		if RunService:IsStudio() and CrownService.getBalance(player) == 0 then
			CrownService.grant(player.UserId, STUDIO_STARTER_CROWNS)
		end

		-- daily login reward: credits scale with streak, small crown stipend
		local p = profiles[player]
		local today = os.date("!%Y-%m-%d")
		if p and p.lastLogin ~= today then
			local yesterday = os.date("!%Y-%m-%d", os.time() - 86400)
			p.loginStreak = (p.lastLogin == yesterday) and ((p.loginStreak or 0) + 1) or 1
			p.lastLogin = today
			local creditReward = math.min(100 + (p.loginStreak - 1) * 25, 250)
			local crownReward = 25
			p.credits += creditReward
			CrownService.grant(player.UserId, crownReward)
			PlayerDataService.notify(
				player,
				("DAILY LOGIN day %d: +%d credits, +%d crowns!"):format(p.loginStreak, creditReward, crownReward)
			)
			saveProfile(player)
		end

		PlayerDataService.pushHUD(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player] = nil
	end)

	-- Autosave sweep
	task.spawn(function()
		while true do
			task.wait(60)
			for player in profiles do
				saveProfile(player)
			end
		end
	end)
end

return PlayerDataService
