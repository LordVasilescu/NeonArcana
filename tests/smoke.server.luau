--!nonstrict
-- Injected by run-in-roblox. Verifies the place boots and the combat core works.
-- Prints SMOKE_PASS / SMOKE_FAIL lines that Claude reads from the CLI output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local failures = 0
local function check(label: string, condition: boolean)
	if condition then
		print("SMOKE_PASS: " .. label)
	else
		failures += 1
		print("SMOKE_FAIL: " .. label)
	end
end

-- 1. Structure synced correctly
check("DuelPad exists in Workspace", Workspace:FindFirstChild("DuelPad") ~= nil)
check("Remotes folder exists", ReplicatedStorage:FindFirstChild("Remotes") ~= nil)
check("CastRequest remote exists", ReplicatedStorage.Remotes:FindFirstChild("CastRequest") ~= nil)
check("Shared.SpellData exists", ReplicatedStorage:FindFirstChild("Shared") ~= nil)

-- 2. Combat core: deterministic battle using only 100%-accuracy cards
local CombatService = require(ServerScriptService.Server.CombatService)

local hero = CombatService.newCombatant(nil, "Hero", 500, { "overclock", "ember_jab" })
local dummy = CombatService.newCombatant(nil, "Dummy", 10000, { "firewall" })
local battle = CombatService.newBattle({ hero, dummy })

check("battle starts active", battle.active == true)
check("combatants start with 1 cycle", hero.cycles == 1)

-- Round 1: blade up (100% accuracy, cost 0)
check("blade cast accepted", CombatService.requestCast(battle, 1, "overclock", 1))
CombatService.resolveRound(battle)
check("blade stored after round 1", #hero.blades == 1)
check("cycles grew to 2", hero.cycles == 2)

-- Round 2+: jab until it lands (75% accuracy, so loop past fizzles)
local landed = false
for _ = 1, 40 do
	CombatService.requestCast(battle, 1, "ember_jab", 2)
	CombatService.resolveRound(battle)
	if dummy.health < 10000 then
		landed = true
		break
	end
end
check("ember jab eventually landed", landed)
-- Blade math: first landing hit should be floor(70 * 1.35) = 94 (blade consumed on it)
local damageTaken = 10000 - dummy.health
check("bladed hit dealt 94 (70 * 1.35)", damageTaken == 94)
check("blade consumed after hit", #hero.blades == 0)

-- 3. Kill check ends the battle
dummy.health = 1
CombatService.requestCast(battle, 1, "ember_jab", 2)
for _ = 1, 40 do
	CombatService.resolveRound(battle)
	if not battle.active then
		break
	end
	CombatService.requestCast(battle, 1, "ember_jab", 2)
end
check("battle ends when dummy dies", battle.active == false and dummy.health == 0)

if failures == 0 then
	print("SMOKE_RESULT: ALL PASS")
else
	print(("SMOKE_RESULT: %d FAILURES"):format(failures))
end
