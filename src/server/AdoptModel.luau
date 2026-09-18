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

-- Clone (or move) a template so its base sits at cframe's position. Anchors all parts.
function AdoptModel.stamp(template: Model, cframe: CFrame, parent: Instance, useOriginal: boolean?): Model
	local instance = useOriginal and template or template:Clone()
	local height = instance:GetExtentsSize().Y
	instance:PivotTo(cframe * CFrame.new(0, height / 2, 0))
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
