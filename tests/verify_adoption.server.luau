--!nonstrict
-- Drives the world builders directly against the saved place (with its imported
-- models) and counts adoptions. Independent of whether Main.server auto-ran.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local HubService = require(ServerScriptService.Server.HubService)
local EnemySpawner = require(ServerScriptService.Server.EnemySpawner)

pcall(HubService.build)
pcall(EnemySpawner.init)
task.wait(2)

local templates = {}
for _, child in ServerStorage:GetChildren() do
	if child:IsA("Model") then
		table.insert(templates, child.Name)
	end
end

local enemyModels = 0
local padsFolder = Workspace:FindFirstChild("EnemyPads")
if padsFolder then
	for _, child in padsFolder:GetChildren() do
		if child:IsA("Model") then
			enemyModels += 1
		end
	end
end

local plazaModels = 0
local plaza = Workspace:FindFirstChild("NeonPlaza")
if plaza then
	for _, child in plaza:GetChildren() do
		if child:IsA("Model") then
			plazaModels += 1
		end
	end
end

print("TEMPLATES: " .. table.concat(templates, ", "))
print(("ADOPTION_RESULT: templates=%d enemyModels=%d plazaModels=%d"):format(#templates, enemyModels, plazaModels))
