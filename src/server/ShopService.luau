--!nonstrict
-- ShopService: Protocol Packs. 100 crowns buys one single-use "treasure card"
-- from ANY school — the only way to cast off-school. Odds are published in the
-- shop UI (Roblox paid-random-item rule) and MUST match ODDS below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpellData = require(ReplicatedStorage.Shared.SpellData)
local CrownService = require(script.Parent.CrownService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyPack = remotes:WaitForChild("BuyPack")

local PACK_COST = 100
-- Published odds: common 60% (0-1 cycle), uncommon 30% (2 cycle), rare 10% (3 cycle)
local ODDS = { common = 0.6, uncommon = 0.3, rare = 0.1 }

local pools = { common = {}, uncommon = {}, rare = {} }
for id, spell in SpellData do
	if spell.cost <= 1 then
		table.insert(pools.common, id)
	elseif spell.cost == 2 then
		table.insert(pools.uncommon, id)
	else
		table.insert(pools.rare, id)
	end
end

local ShopService = {}

local function rollCard(): (string, string)
	local roll = math.random()
	local tier = "common"
	if roll < ODDS.rare then
		tier = "rare"
	elseif roll < ODDS.rare + ODDS.uncommon then
		tier = "uncommon"
	end
	local pool = pools[tier]
	return pool[math.random(#pool)], tier
end

function ShopService.init()
	buyPack.OnServerEvent:Connect(function(player)
		local profile = PlayerDataService.get(player)
		if not profile then
			return
		end
		if not CrownService.trySpend(player, PACK_COST) then
			PlayerDataService.notify(player, ("Not enough Crowns (pack costs %d)."):format(PACK_COST))
			return
		end
		local cardId, tier = rollCard()
		local spell = SpellData[cardId]
		profile.treasureCards = profile.treasureCards or {}
		profile.treasureCards[cardId] = (profile.treasureCards[cardId] or 0) + 1
		PlayerDataService.notify(
			player,
			("PACK OPENED [%s]: %s (%s) — single-use card added to your hand!"):format(
				tier:upper(),
				spell.name,
				spell.school
			)
		)
		PlayerDataService.pushHUD(player)
	end)
end

ShopService.PACK_COST = PACK_COST
ShopService.ODDS = ODDS
return ShopService
