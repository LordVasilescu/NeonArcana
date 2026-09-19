--!nonstrict
-- AdoptModel: shared helpers for adopting Studio-imported models into the world.

local AdoptModel = {}

-- Uniformly scale a model to fit inside fitSize. Returns true on success.
function AdoptModel.scaleToFit(model: Model, fitSize: Vector3): boolean
	return (
		pcall(function()
			local size = model:GetExtentsSize()
			model:ScaleTo(
				math.min(
					fitSize.X / math.max(size.X, 0.001),
					fitSize.Y / math.max(size.Y, 0.001),
					fitSize.Z / math.max(size.Z, 0.001)
				)
			)
		end)
	)
end

-- Uniformly scale a model to a target height, optionally capping its footprint.
-- Buildings use this: fitting them into a fixed box shrank wide models to nothing.
function AdoptModel.scaleToHeight(model: Model, height: number, maxFootprint: number?): boolean
	return (
		pcall(function()
			local size = model:GetExtentsSize()
			local factor = height / math.max(size.Y, 0.001)
			if maxFootprint then
				factor = math.min(factor, maxFootprint / math.max(size.X, size.Z, 0.001))
			end
			model:ScaleTo(factor)
		end)
	)
end

-- World-axis-aligned centre of every BasePart in the model (approximate for rotated
-- parts, which is fine for placement).
local function boundsCenter(model: Model): Vector3
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local half = descendant.Size / 2
			minV = minV:Min(descendant.Position - half)
			maxV = maxV:Max(descendant.Position + half)
		end
	end
	if minV.X == math.huge then
		return model:GetPivot().Position
	end
	return (minV + maxV) / 2
end

local CORNERS = {
	Vector3.new(-1, -1, -1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, 1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, 1, 1),
}

-- Exact lowest point of the model's VISIBLE parts, using each part's rotated corners.
-- Extents/AABB maths is wrong for tilted parts and counts invisible hitboxes, which is
-- why models were floating or sinking by a few studs.
local function lowestVisibleY(model: Model): number?
	local minY = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local cf, half = descendant.CFrame, descendant.Size / 2
			for _, corner in CORNERS do
				local y = (cf * Vector3.new(corner.X * half.X, corner.Y * half.Y, corner.Z * half.Z)).Y
				if not minY or y < minY then
					minY = y
				end
			end
		end
	end
	return minY
end

-- Drop (or lift) a placed model so its lowest visible point sits exactly on floorY.
function AdoptModel.settle(model: Model, floorY: number)
	local minY = lowestVisibleY(model)
	if minY then
		local delta = floorY - minY
		if math.abs(delta) > 0.005 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, delta, 0))
		end
	end
end

-- Clone (or move) a template so its base sits at cframe's position. Anchors all parts.
function AdoptModel.stamp(template: Model, cframe: CFrame, parent: Instance, useOriginal: boolean?): Model
	local instance = useOriginal and template or template:Clone()
	local height = instance:GetExtentsSize().Y
	-- Store models often carry a pivot that is off-centre or rotated; PivotTo would then
	-- float, sink, or tip the model. Reset it to an upright pivot at the bounds centre.
	instance.WorldPivot = CFrame.new(boundsCenter(instance))
	instance:PivotTo(cframe * CFrame.new(0, height / 2, 0))
	AdoptModel.settle(instance, cframe.Position.Y)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	instance.Parent = parent
	return instance
end

return AdoptModel
