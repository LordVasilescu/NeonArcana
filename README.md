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

**Option B — Rojo (the real workflow, fully set up):**
1. Install Rokit (`winget install Rojo.Rokit`), then in this folder run `rokit install`.
   That gives you rojo, stylua, selene, luau-lsp, run-in-roblox, wally, lune, rbxcloud.
2. `rojo serve` and connect the Rojo plugin in Studio; scripts sync live and Git keeps history.
3. `build\NeonArcana.rbxl` is the canonical Studio-saved place (it holds the imported
   models). Never overwrite it with `rojo build`; open it in Studio and save there.

## Dev stack
| Tool | Purpose |
|---|---|
| Rojo | syncs `src/` into Studio, builds place files, generates the sourcemap |
| StyLua / Selene | formatting and linting |
| luau-lsp | type checking against Roblox API types (`globalTypes.d.luau`, auto-downloaded) |
| run-in-roblox | runs `tests/smoke.server.luau` inside Studio from the CLI |
| Wally | Roblox package manager (`wally init` when the first dependency lands) |
| Lune | Luau runtime outside Studio, for scripts and fast unit tests |
| rbxcloud | Open Cloud CLI for publishing place updates without Studio |
| Blender + Python 3 | Tripo asset conversion and previews (`tools/`); Blender found automatically or via `BLENDER_PATH` |
| VS Code | `.vscode/` has settings and recommended extensions (Rojo, Luau LSP, StyLua, Selene) |

**Quality gate:** `.\tools\check.ps1` runs format check, lint, type check, build, and the
Studio smoke test. `-Fast` skips Studio, `-Fix` auto-formats first. The same gate minus
Studio runs on every push via GitHub Actions (`.github/workflows/ci.yml`) and as a
pre-commit hook once you run `git config core.hooksPath .githooks`.

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
