--!nonstrict
-- MeshVisuals: turns uploaded Tripo meshes (MeshAssets ids) into world objects.
-- Silently no-ops for assets that aren't uploaded yet or when Studio is offline,
-- so the procedural placeholders keep working until real models arrive.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshAssets = require(ReplicatedStorage.Shared.MeshAssets)

local MeshVisuals = {}

-- Places mesh `name` at `cframe`, uniformly scaled to fit inside `fitSize`.
-- Returns the MeshPart, or nil if the asset isn't available.
function MeshVisuals.place(name: string, cframe: CFrame, fitSize: Vector3, parent: Instance): MeshPart?
	local id = MeshAssets[name]
	if not id then
		return nil
	end
	local ok, mesh = pcall(function()
		return InsertService:CreateMeshPartAsync(Content.fromUri(id))
	end)
	if not ok or not mesh then
		warn("[MeshVisuals] failed to load " .. name .. ": " .. tostring(mesh))
		return nil
	end
	mesh.Name = "Mesh_" .. name
	mesh.Anchored = true
	mesh.CanCollide = false
	local size = mesh.Size
	local scale = math.min(fitSize.X / size.X, fitSize.Y / size.Y, fitSize.Z / size.Z)
	mesh.Size = size * scale
	-- rest the scaled mesh's base on the cframe position
	mesh.CFrame = cframe * CFrame.new(0, mesh.Size.Y / 2, 0)
	mesh.Parent = parent
	return mesh
end

function MeshVisuals.available(name: string): boolean
	return MeshAssets[name] ~= nil
end

return MeshVisuals
