--!nonstrict
--# selene: allow(incorrect_standard_library_use)
-- Test harness for Lune (runs outside Studio, no Roblox engine). Installs the few
-- Roblox globals the shared/server modules under test touch, then exposes check().
-- Run everything with:  lune run tests/lune/run
-- (luau-lsp skips this folder: the @lune requires and global stubs are Lune-only.)

local roblox = require("@lune/roblox")

local SHARED = "../../src/shared/"

-- `require(ReplicatedStorage.Shared.X)` inside src resolves through this table to a
-- path relative to the requiring file (src/server/*).
local sharedPaths = setmetatable({}, {
	__index = function(_, name)
		return "../shared/" .. name
	end,
})

game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return { Shared = sharedPaths }
		end
		error("harness: no stub for service " .. tostring(name))
	end,
}

Random = {
	new = function(seed)
		local gen = { seed = seed }
		function gen:NextNumber(a, b)
			if a and b then
				return a + (b - a) * math.random()
			end
			return math.random()
		end
		function gen:NextInteger(a, b)
			return math.random(a, b)
		end
		return gen
	end,
}

-- fixed seed: fizzle rolls are random, a stable seed keeps the pass count reproducible
math.randomseed(20260918)

Vector3 = roblox.Vector3
Color3 = roblox.Color3

local Harness = {}
Harness.passed = 0
Harness.failed = 0

function Harness.check(label: string, condition: boolean, detail: any?)
	if condition then
		Harness.passed += 1
	else
		Harness.failed += 1
		print("FAIL: " .. label .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end

function Harness.shared(name: string)
	return require(SHARED .. name)
end

return Harness
