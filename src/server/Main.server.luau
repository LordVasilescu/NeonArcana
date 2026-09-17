--!strict
-- Bootstrap: the only Script (vs ModuleScript) on the server. Wires services up.

local ServerScriptService = game:GetService("ServerScriptService")

require(ServerScriptService.Server.CrownService) -- load-bearing: registers MarketplaceService.ProcessReceipt
local CombatService = require(ServerScriptService.Server.CombatService)

print("[NeonArcana] Server booted. Crown + Combat services loaded.")
print("[NeonArcana] Combat select timer:", CombatService.SELECT_TIME, "seconds")

-- Smoke test: run a scripted 1v1 so we know the combat core works in Studio.
-- Delete once the real duel circles exist.
task.delay(3, function()
	local hero = CombatService.newCombatant(nil, "TestRunner", 500, { "spark_jab", "overclock_blade" })
	local dummy = CombatService.newCombatant(nil, "TrainingDummy", 300, { "frost_packet" })
	local battle = CombatService.newBattle({ hero, dummy })

	CombatService.requestCast(battle, 1, "overclock_blade", 1)
	CombatService.resolveRound(battle)
	CombatService.requestCast(battle, 1, "spark_jab", 2)
	CombatService.resolveRound(battle)

	print(("[NeonArcana] Smoke test: dummy at %d/%d HP after blade+jab"):format(dummy.health, dummy.maxHealth))
end)
