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
| Lune | Luau runtime outside Studio; runs the unit tests in `tests/lune/` (`lune run tests/lune/run`) |
| rbxcloud | Open Cloud CLI for publishing place updates without Studio |
| Blender + Python 3 | Tripo asset conversion and previews (`tools/`); Blender found automatically or via `BLENDER_PATH` |
| VS Code | `.vscode/` has settings and recommended extensions (Rojo, Luau LSP, StyLua, Selene) |

**Quality gate:** `.\tools\check.ps1` runs format check, lint, Lune unit tests (combat math +
data integrity, no Studio needed), type check, build, and the Studio smoke test. `-Fast` skips
Studio, `-Fix` auto-formats first. The same gate minus Studio runs on every push via GitHub
Actions (`.github/workflows/ci.yml`) and as a pre-commit hook once you run
`git config core.hooksPath .githooks`.

## Playing the current code
`.\tools\play.ps1` builds `build\NeonArcana.demo.rbxl` (canonical world + current `src/`),
opens it in Studio on the primary monitor and presses Play. The canonical place is only read.

## Store models (world props)
Street buildings, lamps, vehicles, clutter, kiosks, chests and Fixer NPCs are free Creator
Store models listed in `src/server/PremadeAssets.luau`. `InsertService:LoadAsset` refuses
them until the place is published, so for local play they ride along in
`assets/store_models.rbxm`, which `tools/build_demo` injects into `ServerStorage.StoreModels`.
To add or change models: edit the pools, paste `tools/fetch_store_models.luau` into Studio's
command bar (edit mode) with the same ids, File -> Save to File, then
`lune run tools/extract_store_models`. Every builder keeps a procedural fallback.

## Before monetization works
1. Publish the game (File → Publish to Roblox).
2. Creator Dashboard → your game → Monetization → Developer Products →
   create the 4 crown packs from the GDD.
3. Paste each product ID into `CROWN_PRODUCTS` in `CrownService.luau`.
4. Enable Studio API access (Game Settings → Security) so DataStores work in Studio.

## What exists / what's next
Phase 1 (Wizard City parity) is done; see `ROADMAP.md` for the full list.
- [x] 7 schools, 35 spells, school selection, deck editor
- [x] Turn-based combat core: cycles (pips), blades, traps, shields, DoTs, fizzles
- [x] Group combat (up to 4v4 shared circles) and a plaza PvP duel pad
- [x] Neon Plaza hub + 4 districts, main quest chain, side quests, chests, gear drops
- [x] Player save data (DataStore, autosave, shutdown flush), daily login rewards
- [x] Crowns: idempotent receipts, premium zone gate, card packs, hoverboard mount
- [x] Combat UI, HUD, shop/deck panels, sound layer
- [ ] Publish + create the 4 crown Dev Products (see `PUBLISH_CHECKLIST.md`)
- [ ] Mesh uploads via Open Cloud, game icon/thumbnails
