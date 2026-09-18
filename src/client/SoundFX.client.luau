--!nonstrict
-- SoundFX: audio layer built entirely from guaranteed rbxasset:// built-ins
-- (no marketplace ids that can go private). Pitch-shifted for variety.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local battleState = remotes:WaitForChild("BattleState")
local battleEnd = remotes:WaitForChild("BattleEnd")
local notifyRemote = remotes:WaitForChild("Notify")

local function makeSound(name: string, file: string, volume: number, speed: number?): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxasset://sounds/" .. file
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.Parent = SoundService
	return sound
end

local sounds = {
	deal = makeSound("CardDeal", "volume_slider.ogg", 0.5, 1.2),
	hit = makeSound("SpellHit", "impact_explosion_03.mp3", 0.45, 1),
	burn = makeSound("BurnTick", "impact_explosion_03.mp3", 0.25, 1.6),
	fizzle = makeSound("Fizzle", "oof.ogg", 0.6, 0.9),
	heal = makeSound("Heal", "volume_slider.ogg", 0.5, 1.7),
	hurt = makeSound("Hurt", "ouch.ogg", 0.5, 1),
	win = makeSound("Win", "action_jump_land.mp3", 0.7, 1.3),
	lose = makeSound("Lose", "oof.ogg", 0.7, 0.6),
	ping = makeSound("Ping", "volume_slider.ogg", 0.35, 1.45),
}

local rng = Random.new()
local function play(sound: Sound, baseSpeed: number?)
	-- slight pitch wobble so repeats don't grate
	sound.PlaybackSpeed = (baseSpeed or 1) * rng:NextNumber(0.92, 1.08)
	sound:Play()
end

battleState.OnClientEvent:Connect(function(payload)
	if payload.phase == "select" then
		play(sounds.deal, 1.2)
		return
	end
	local events = payload.state and payload.state.events or {}
	local played = {}
	for _, line in events do
		if line:find("FIZZLED") and not played.fizzle then
			played.fizzle = true
			play(sounds.fizzle, 0.9)
		elseif line:find("damage") and not played.hit then
			played.hit = true
			play(sounds.hit, 1)
		elseif line:find("burns") and not played.burn then
			played.burn = true
			play(sounds.burn, 1.6)
		elseif line:find("healed") and not played.heal then
			played.heal = true
			play(sounds.heal, 1.7)
		end
	end
end)

battleEnd.OnClientEvent:Connect(function(payload)
	if payload.won then
		play(sounds.win, 1.3)
	else
		play(sounds.lose, 0.6)
	end
end)

notifyRemote.OnClientEvent:Connect(function()
	play(sounds.ping, 1.45)
end)

-- ambient night-city wind, looped low
local ambient = Instance.new("Sound")
ambient.Name = "CityAmbience"
ambient.SoundId = "rbxasset://sounds/action_falling.ogg"
ambient.Volume = 0.07
ambient.PlaybackSpeed = 0.55
ambient.Looped = true
ambient.Parent = SoundService
ambient:Play()
