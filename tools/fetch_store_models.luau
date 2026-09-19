-- Paste into Roblox Studio's COMMAND BAR (edit mode) and run. Not a game script.
-- Pulls every Creator Store model PremadeAssets knows about into
-- ServerStorage.StoreModels using YOUR Studio login, which works before the place is
-- published (InsertService:LoadAsset does not). Then File -> Save to File, and run
--   lune run tools/extract_store_models
-- to refresh assets/store_models.rbxm, which tools/build_demo injects into every demo.
-- Keep this id list in sync with src/server/PremadeAssets.luau (ids + pools).
local ids = {
	77342670464136, 157006174,
	-- tower
	368735037, 4650148408, 2785172284, 10857713656, 3512150174, 5639505034, 12940385658, 5275971356, 11465941994, 94248714986191,
	-- lamp
	10490666250, 15472204631, 14212653287, 13617909379, 8389194577, 565846542,
	-- vehicle
	8415362501, 10049043385, 11127676539, 15980632130, 91436697537679,
	-- prop
	10904552162, 5958066055, 96257169, 8933830009, 8933826663, 103340928, 7111068101,
	-- sign
	17622248801, 269085542, 9832019855, 286192792,
	-- kiosk
	12266224495, 92641446521110, 13316060284,
	-- fixer
	4537150682, 117423747775868, 14690760325,
	-- chest
	11867606381, 8655778958, 15423731190,
}
local f = game.ServerStorage:FindFirstChild("StoreModels") or Instance.new("Folder")
f.Name = "StoreModels"
f.Parent = game.ServerStorage
local fetched, failed = 0, 0
for _, id in ids do
	if not f:FindFirstChild("asset_" .. id) then
		local ok, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		if ok then
			local holder = Instance.new("Model")
			holder.Name = "asset_" .. id
			for _, o in objs do
				o.Parent = holder
			end
			holder.Parent = f
			fetched += 1
		else
			failed += 1
			warn("STOREFETCH failed " .. id .. ": " .. tostring(objs))
		end
	end
end
print(("STOREFETCH done: %d in folder, %d new, %d failed"):format(#f:GetChildren(), fetched, failed))
