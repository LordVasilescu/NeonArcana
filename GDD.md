# NEON ARCANA — Game Design Doc (v0.1)

**Pitch:** Turn-based spell-dueling MMO in a cyberpunk megacity. Wizard101's combat
loop and progression, reskinned as netrunners casting "protocols" instead of wizards
casting spells. You're not a wizard — you're a **Codeslinger**.

## Core Loop (stolen from what works)
1. Walk around a district (world) → get pulled into turn-based combat vs gangers/rogue AI
2. Combat = card-based, pips-style resource system, school advantages
3. Win → XP, drops, currency → new protocols (spells), gear, cyberware
4. Story quests gate each district; side content everywhere

## Schools → "Protocols" (7, mirroring W101's structure)
| W101 equivalent | Ours        | Flavor                          |
|-----------------|-------------|---------------------------------|
| Fire            | **Burnout** | Overclock damage-over-time      |
| Ice             | **Coolant** | Tanky, shields, stalls          |
| Storm           | **Surge**   | High damage, low accuracy       |
| Life            | **Patch**   | Healing, repair drones          |
| Death           | **Leech**   | Drain, debuffs                  |
| Myth            | **Ghost**   | Summons, holograms, minions     |
| Balance         | **Kernel**  | Jack-of-all, buffs the team     |

## Combat (the W101 formula)
- Circle arena, up to 4v4, turn-based, simultaneous card selection with a timer
- **Pips** → "Cycles": gain 1/turn, power cycles (worth 2) chance scales with level
- Cards have accuracy %, cycle cost, school. Fizzle = wasted turn
- Blades/traps/shields/wards all translate 1:1 (buff stacking is the depth)

## Districts (worlds) — launch with 1, roadmap 5
1. **The Sprawl** (tutorial city, lvl 1–10) — LAUNCH
2. Neon Gardens (corpo arcology, 10–20)
3. The Undergrid (sewers/old net, 20–30)
4. Chrome Coast (beach/casino district, 30–40)
5. Blacksite Zero (endgame raid zone, 40–50)

## Monetization — "Neon Crowns" (the Wizard101 playbook, Roblox rules)
Premium currency bought with **Robux via Developer Products**. Never sell power
directly at first — sell access, convenience, and drip. Spend Crowns on:
- **Area unlocks** (W101's zone-gating — their single biggest earner)
- **Energy refills** (side activities like drone farming use energy)
- **Card packs** (gacha: cosmetics + rare protocols) — MUST show odds (Roblox policy)
- **Mounts/hoverboards** (speed = the classic whale magnet)
- **Cosmetics**: chrome, jackets, weapon skins, name effects
- Optional **"Membership" gamepass**: all zones + daily crown stipend

### Crown packages (Dev Products)
| Robux | Crowns | Bonus |
|-------|--------|-------|
| 99    | 500    | —     |
| 399   | 2,250  | +12%  |
| 799   | 5,000  | +25%  |
| 1,999 | 13,500 | +35%  |

### Revenue reality check
DevEx ≈ $0.0038/Robux after Roblox's cut on marketplace items varies; dev products
pay ~70% of Robux spent to you. $100k/month ≈ ~26M earned Robux/month. Path:
ship small → retain → update weekly → paid ads (Roblox sponsored) once LTV > cost.

## Legal guardrails
- No W101 names, art, spell names, sounds, or map layouts. Mechanics aren't
  copyrightable; expression is. "Inspired by" only.
- Gacha packs: publish odds in-game (Roblox requirement).

## MVP cut (get playable in weeks, not years)
- 1 district hub, 3 schools (Burnout/Coolant/Patch), 15 cards each
- PvE duel circles with 3 enemy types + 1 boss
- Crowns purchase flow + area gate + 1 mount
- DataStore save: level, deck, crowns, unlocks
