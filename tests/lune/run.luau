--!nonstrict
-- Runs every spec in this folder. Exit code 1 on any failure.
--   lune run tests/lune/run

local process = require("@lune/process")
local T = require("./harness")

require("./combat.spec")
require("./data.spec")

print(("LUNE_RESULT: %d passed, %d failed"):format(T.passed, T.failed))
if T.failed > 0 then
	process.exit(1)
end
