--!nonstrict
-- PremadeAssets: free Creator Store models as a fallback tier when our Tripo
-- pipeline has a gap. SECURITY: every script inside an inserted asset is
-- destroyed before the model touches the world — free models can carry malware.

local InsertService = game:GetService("InsertService")

local PremadeAssets = {}

-- slot name -> free Creator Store asset id (audited by hand before adding)
PremadeAssets.ids = {
	grid_stalker = 77342670464136, -- "Horror Wolf Wendigo Monster R15 - NPC no Scripted"
}

function PremadeAssets.load(assetId: number): Model?
	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not container then
		warn("[PremadeAssets] failed to load asset " .. tostring(assetId) .. ": " .. tostring(container))
		return nil
	end
	local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
	if not model then
		container:Destroy()
		return nil
	end
	if model:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		model.Parent = wrapper
		model = wrapper
	end
	-- strip ALL scripts: free models are untrusted code until proven otherwise
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
	model.Parent = nil
	container:Destroy()
	return model
end

return PremadeAssets
