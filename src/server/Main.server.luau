--!strict
-- Bootstrap: the only Script (vs ModuleScript) on the server. Wires services up.

local ServerScriptService = game:GetService("ServerScriptService")

require(ServerScriptService.Server.CrownService) -- load-bearing: registers MarketplaceService.ProcessReceipt
local BattleRunner = require(ServerScriptService.Server.BattleRunner)

BattleRunner.init()
print("[NeonArcana] Server booted. Step on the neon DuelPad to fight.")
