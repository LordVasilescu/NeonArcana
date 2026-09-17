# Neon Arcana

Cyberpunk turn-based spell-dueling MMO for Roblox. See `GDD.md` for the full design.

## Getting the code into Roblox Studio

**Option A — copy/paste (fastest to start):**
1. Install [Roblox Studio](https://create.roblox.com/) and make a new Baseplate place.
2. In the Explorer:
   - `ReplicatedStorage` → add Folder named `Shared` → add ModuleScript `SpellData`,
     paste `src/shared/SpellData.luau`
   - `ServerScriptService` → add ModuleScripts `CombatService` and `CrownService`,
     paste from `src/server/`
   - Fix the require path in CombatService if needed
     (`ReplicatedStorage.Shared.SpellData`).

**Option B — Rojo (proper workflow, recommended once serious):**
1. `winget install Rojo.Rojo` (or use the Aftman/Rokit toolchain)
2. Rojo syncs these files into Studio live, and you keep Git history.
   Ask Claude to generate the `default.project.json` when ready.

## Before monetization works
1. Publish the game (File → Publish to Roblox).
2. Creator Dashboard → your game → Monetization → Developer Products →
   create the 4 crown packs from the GDD.
3. Paste each product ID into `CROWN_PRODUCTS` in `CrownService.luau`.
4. Enable Studio API access (Game Settings → Security) so DataStores work in Studio.

## What exists / what's next
- [x] Card/spell data model (3 schools, 7 cards)
- [x] Turn-based combat core: cycles (pips), blades, traps, shields, DoTs, fizzles
- [x] Crown purchase + spend service (idempotent receipts, server-authoritative)
- [ ] Duel circle: touch a pad in the world → battle starts vs NPC
- [ ] Combat UI: card hand, timer, health bars
- [ ] Player save data (level, XP, deck, unlocks)
- [ ] Crown shop UI + first zone gate
- [ ] The Sprawl: greybox the hub map
