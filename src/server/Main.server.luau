--!strict
-- Bootstrap: the only Script (vs ModuleScript) on the server. Wires services up.

local ServerScriptService = game:GetService("ServerScriptService")

require(ServerScriptService.Server.CrownService) -- load-bearing: registers MarketplaceService.ProcessReceipt
local PlayerDataService = require(ServerScriptService.Server.PlayerDataService) :: any
local BattleRunner = require(ServerScriptService.Server.BattleRunner) :: any
local ZoneService = require(ServerScriptService.Server.ZoneService) :: any
local EnemySpawner = require(ServerScriptService.Server.EnemySpawner) :: any

PlayerDataService.init()
BattleRunner.init()
ZoneService.build()
EnemySpawner.init()

print("[NeonArcana] Server booted: Neon Plaza + 3 districts live. Pick a school, choom.")
