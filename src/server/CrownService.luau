--!strict
-- CrownService: premium currency ("Neon Crowns") via Roblox Developer Products.
-- CRITICAL RULES:
--   1. ProcessReceipt must be idempotent (Roblox can call it twice for one purchase).
--   2. Only grant AFTER the save succeeds, then return PurchaseGranted.
--   3. Never trust the client with balances — all spends validated here.

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- pcall: DataStores are unavailable in unpublished/offline Studio sessions.
-- Balances then live in memory only, which is exactly what you want for testing.
local function tryGetStore(name: string): DataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	return if ok then store else nil
end

local crownStore = tryGetStore("Crowns_v1")
local receiptStore = tryGetStore("Receipts_v1")
if not crownStore then
	warn("[CrownService] DataStores unavailable (offline Studio?) — using in-memory balances")
end

-- Fill these in after creating Dev Products in the Creator Dashboard
local CROWN_PRODUCTS: { [number]: number } = {
	-- [devProductId] = crownsGranted
	-- [1234567890] = 500,    -- 99 Robux pack
	-- [1234567891] = 2250,   -- 399 Robux pack
	-- [1234567892] = 5000,   -- 799 Robux pack
	-- [1234567893] = 13500,  -- 1999 Robux pack
}

local CrownService = {}
local balanceCache: { [number]: number } = {} -- userId -> crowns

local function loadBalance(userId: number): number
	if balanceCache[userId] then
		return balanceCache[userId]
	end
	local value = nil
	if crownStore then
		local loaded, result = pcall(function()
			return crownStore:GetAsync(tostring(userId))
		end)
		if loaded then
			value = result
		end
	end
	balanceCache[userId] = if typeof(value) == "number" then value else 0
	return balanceCache[userId]
end

local function saveBalance(userId: number): boolean
	if not crownStore then
		return true -- in-memory mode: the cache IS the store
	end
	local saved = pcall(function()
		crownStore:SetAsync(tostring(userId), balanceCache[userId] or 0)
	end)
	return saved
end

function CrownService.getBalance(player: Player): number
	return loadBalance(player.UserId)
end

-- Returns true if the spend went through. Use for zone unlocks, packs, mounts, etc.
function CrownService.trySpend(player: Player, amount: number): boolean
	assert(amount > 0 and amount == math.floor(amount), "invalid spend amount")
	local balance = loadBalance(player.UserId)
	if balance < amount then
		return false
	end
	balanceCache[player.UserId] = balance - amount
	if not saveBalance(player.UserId) then
		balanceCache[player.UserId] = balance -- roll back on save failure
		return false
	end
	return true
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local crowns = CROWN_PRODUCTS[receiptInfo.ProductId]
	if not crowns then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Idempotency: bail if we've already granted this receipt
	local receiptKey = receiptInfo.PurchaseId
	if receiptStore then
		local alreadyGranted = false
		local checked = pcall(function()
			alreadyGranted = receiptStore:GetAsync(receiptKey) == true
		end)
		if not checked then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if alreadyGranted then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local userId = receiptInfo.PlayerId
	local balance = loadBalance(userId)
	balanceCache[userId] = balance + crowns
	if not saveBalance(userId) then
		balanceCache[userId] = balance
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end

	if receiptStore then
		pcall(function()
			receiptStore:SetAsync(receiptKey, true)
		end)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerRemoving:Connect(function(player)
	saveBalance(player.UserId)
	balanceCache[player.UserId] = nil
end)

return CrownService
