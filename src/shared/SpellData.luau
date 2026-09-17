--!strict
-- SpellData: full 7-school card set, W101-style accuracy/cost curves.
-- Server is ALWAYS the authority on what a card actually does.

export type SpellEffect = {
	kind: "Damage" | "Heal" | "Blade" | "Trap" | "Shield" | "DoT",
	amount: number, -- damage/heal value, or percent for blade/trap/shield
	ticks: number?, -- for DoT: number of rounds
}

export type Spell = {
	id: string,
	name: string,
	school: "Burnout" | "Coolant" | "Surge" | "Patch" | "Leech" | "Ghost" | "Kernel",
	cost: number, -- cycles (pips)
	accuracy: number, -- 0-100; per-school identity: Surge lowest, Patch highest
	levelReq: number,
	effects: { SpellEffect },
	description: string,
}

local Spells: { [string]: Spell } = {}

local function spell(
	id: string,
	name: string,
	school: any,
	cost: number,
	accuracy: number,
	levelReq: number,
	effects: { SpellEffect },
	description: string
)
	Spells[id] = {
		id = id,
		name = name,
		school = school,
		cost = cost,
		accuracy = accuracy,
		levelReq = levelReq,
		effects = effects,
		description = description,
	}
end

local function dmg(n: number): SpellEffect
	return { kind = "Damage", amount = n }
end
local function heal(n: number): SpellEffect
	return { kind = "Heal", amount = n }
end
local function blade(n: number): SpellEffect
	return { kind = "Blade", amount = n }
end
local function trap(n: number): SpellEffect
	return { kind = "Trap", amount = n }
end
local function shield(n: number): SpellEffect
	return { kind = "Shield", amount = n }
end
local function dot(n: number, t: number): SpellEffect
	return { kind = "DoT", amount = n, ticks = t }
end

-- BURNOUT (fire): damage-over-time school, 75%
spell("ember_jab", "Ember Jab", "Burnout", 1, 75, 1, { dmg(70) }, "A quick jolt of overclocked current.")
spell("overclock", "Overclock", "Burnout", 0, 100, 1, { blade(35) }, "+35% to your next Burnout hit.")
spell("thermal_bleed", "Thermal Bleed", "Burnout", 2, 75, 5, { dot(55, 3) }, "Cook their heatsinks: 55 x 3 rounds.")
spell("backdraft", "Backdraft", "Burnout", 0, 100, 8, { trap(30) }, "+30% to the next hit on this target.")
spell("meltdown", "Meltdown", "Burnout", 3, 75, 10, { dmg(310) }, "Total thermal failure. Theirs.")

-- COOLANT (ice): tank school, 85%
spell("frost_packet", "Frost Packet", "Coolant", 1, 85, 1, { dmg(65) }, "Compressed liquid-nitro code.")
spell("firewall", "Firewall", "Coolant", 0, 100, 1, { shield(70) }, "-70% from the next incoming hit.")
spell("cryo_spike", "Cryo Spike", "Coolant", 2, 85, 5, { dmg(150) }, "A spear of frozen packets.")
spell("subzero_edge", "Subzero Edge", "Coolant", 0, 100, 8, { blade(30) }, "+30% to your next Coolant hit.")
spell("glacier_crash", "Glacier Crash", "Coolant", 3, 85, 10, { dmg(240) }, "Drop the whole cold-storage rack.")

-- SURGE (storm): glass cannon, 70%
spell("static_shock", "Static Shock", "Surge", 1, 70, 1, { dmg(105) }, "Raw voltage, no surge protector.")
spell("surge_blade", "Surge Blade", "Surge", 0, 100, 1, { blade(40) }, "+40% to your next Surge hit.")
spell("arc_flash", "Arc Flash", "Surge", 2, 70, 5, { dmg(225) }, "Blinding arc across the rails.")
spell("emp_trap", "EMP Trap", "Surge", 0, 100, 8, { trap(35) }, "+35% to the next hit on this target.")
spell("voltage_dump", "Voltage Dump", "Surge", 3, 70, 10, { dmg(340) }, "The whole grid, straight to the face.")

-- PATCH (life): healer, 90%
spell("nano_sting", "Nano Sting", "Patch", 1, 90, 1, { dmg(55) }, "A swarm of repair nanites, weaponized.")
spell("hotfix", "Hotfix", "Patch", 1, 90, 1, { heal(120) }, "Emergency repair subroutine.")
spell("exploit", "Exploit", "Patch", 0, 100, 5, { trap(30) }, "+30% to the next hit on this target.")
spell("system_restore", "System Restore", "Patch", 2, 90, 8, { heal(280) }, "Roll back to a healthier build.")
spell("rootkit_crush", "Rootkit Crush", "Patch", 3, 90, 10, { dmg(200) }, "Total access. Total control.")

-- LEECH (death): drain school, 85%
spell("siphon", "Siphon", "Leech", 1, 85, 1, { dmg(65), heal(30) }, "Drain their charge into yours.")
spell("corrupt_blade", "Corrupt Blade", "Leech", 0, 100, 1, { blade(30) }, "+30% to your next Leech hit.")
spell("data_drain", "Data Drain", "Leech", 2, 85, 5, { dmg(140), heal(70) }, "Copy, paste, delete original.")
spell("hex_trap", "Hex Trap", "Leech", 0, 100, 8, { trap(30) }, "+30% to the next hit on this target.")
spell("memory_wipe", "Memory Wipe", "Leech", 3, 85, 10, { dmg(230), heal(115) }, "They won't remember losing.")

-- GHOST (myth): tricks and double hits, 80%
spell("specter_bolt", "Specter Bolt", "Ghost", 1, 80, 1, { dmg(75) }, "A shot from nowhere.")
spell("ghost_blade", "Ghost Blade", "Ghost", 0, 100, 1, { blade(35) }, "+35% to your next Ghost hit.")
spell("hologram_strike", "Hologram Strike", "Ghost", 2, 80, 5, { dmg(80), dmg(80) }, "Two of you. Both real enough.")
spell("phase_shield", "Phase Shield", "Ghost", 0, 100, 8, { shield(65) }, "-65% from the next incoming hit.")
spell("poltergeist", "Poltergeist Swarm", "Ghost", 3, 80, 10, { dmg(250) }, "The net remembers its dead.")

-- KERNEL (balance): jack of all trades, 85%
spell("null_strike", "Null Strike", "Kernel", 1, 85, 1, { dmg(70) }, "Segfault to the skull.")
spell("kernel_boost", "Kernel Boost", "Kernel", 0, 100, 1, { blade(25) }, "+25% to your next Kernel hit.")
spell("fork_bomb", "Fork Bomb", "Kernel", 2, 85, 5, { dmg(75), dmg(75) }, "It multiplies. That's the problem.")
spell("sandbox", "Sandbox", "Kernel", 0, 100, 8, { shield(65) }, "-65% from the next incoming hit.")
spell("sudo_smash", "Sudo Smash", "Kernel", 3, 85, 10, { dmg(245) }, "Permission granted. Unfortunately for them.")

return Spells
