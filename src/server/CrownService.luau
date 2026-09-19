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

local LOAD_RETRIES = 2

-- Returns the balance and whether it can be trusted. A failed DataStore read must
-- never be cached as 0: the next save would wipe crowns the player paid for.
local function loadBalance(userId: number): (number, boolean)
	if balanceCache[userId] then
		return balanceCache[userId], true
	end
	if not crownStore then
		balanceCache[userId] = 0
		return 0, true
	end
	for attempt = 1, LOAD_RETRIES do
		local loaded, result = pcall(function()
			return crownStore:GetAsync(tostring(userId))
		end)
		if loaded then
			balanceCache[userId] = if typeof(result) == "number" then result else 0
			return balanceCache[userId], true
		end
		warn(("[CrownService] load %d/%d failed for %d: %s"):format(attempt, LOAD_RETRIES, userId, tostring(result)))
		if attempt < LOAD_RETRIES then
			task.wait(1)
		end
	end
	return 0, false
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
	local balance = loadBalance(player.UserId)
	return balance
end

-- Server-side grant (receipts, quest rewards, Studio test wallets). NEVER expose to a remote.
-- Returns false if the balance could not be loaded (the grant is dropped, not applied to 0).
function CrownService.grant(userId: number, amount: number): boolean
	local balance, ok = loadBalance(userId)
	if not ok then
		warn(("[CrownService] grant of %d to %d skipped: balance unavailable"):format(amount, userId))
		return false
	end
	balanceCache[userId] = balance + amount
	saveBalance(userId)
	return true
end

-- Returns true if the spend went through. Use for zone unlocks, packs, mounts, etc.
function CrownService.trySpend(player: Player, amount: number): boolean
	assert(amount > 0 and amount == math.floor(amount), "invalid spend amount")
	local balance, ok = loadBalance(player.UserId)
	if not ok or balance < amount then
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
	local balance, ok = loadBalance(userId)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
	end
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
