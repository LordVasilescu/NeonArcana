--!strict
-- Bootstrap: the only Script (vs ModuleScript) on the server. Wires services up.

local ServerScriptService = game:GetService("ServerScriptService")

require(ServerScriptService.Server.CrownService) -- load-bearing: registers MarketplaceService.ProcessReceipt
local PlayerDataService = require(ServerScriptService.Server.PlayerDataService) :: any
local BattleRunner = require(ServerScriptService.Server.BattleRunner) :: any
local ZoneService = require(ServerScriptService.Server.ZoneService) :: any
local HubService = require(ServerScriptService.Server.HubService) :: any
local EnemySpawner = require(ServerScriptService.Server.EnemySpawner) :: any
local ChestService = require(ServerScriptService.Server.ChestService) :: any
local ShopService = require(ServerScriptService.Server.ShopService) :: any
local PvPService = require(ServerScriptService.Server.PvPService) :: any
local PremadeAssets = require(ServerScriptService.Server.PremadeAssets) :: any
local WorldLighting = require(ServerScriptService.Server.WorldLighting) :: any

WorldLighting.apply()
PlayerDataService.init()
ShopService.init()
ShopService.initMounts()
BattleRunner.init()
-- Store models for world props load in parallel up front so the builders stamp instantly.
PremadeAssets.preload()
HubService.build()
ZoneService.build()
EnemySpawner.init()
ChestService.init()
PvPService.init()

print("[NeonArcana] Server booted: Neon Plaza + 3 districts live. Pick a school, choom.")
