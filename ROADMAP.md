# Neon Arcana - Development Roadmap

Work top to bottom. Every item: implement -> stylua/selene -> rojo build -> run-in-roblox
smoke test -> commit. Add smoke checks for new systems as they land.

## Phase 1 - Wizard City parity (CURRENT)
- [x] 7 schools, 35 spells, school selection
- [x] 4 districts + hub, quest chain, 8 enemy types, 2 bosses
- [x] XP/levels, credits, crowns, premium gate (Mainframe Blvd)
- [x] Night city: skyline, lamps, fog (brightened for visibility)
- [x] Gear system: visor/jacket/boots stat items, enemy drops, auto-equip upgrades
- [x] Side quests: 7 street jobs via Fixer NPCs at every street mouth, parallel tracking
- [x] Treasure chests: data caches in all streets + plaza, credits + gear rolls, cooldowns
- [x] Boss drops: Glitch Crown / Overseer Halo guaranteed (chance=1 drop tables)
- [x] Neon Plaza (Commons): fountain, 7 school pylons, 3 shop kiosks, Chief Codewright
- [x] Tripo asset generation: 17 models exported (enemies, commons set, props, hoverboards)
- [x] Deck editor UI: DECK button, 7-slot loadout, server-validated custom decks
- [x] Card packs: Protocol Packs 100 crowns, single-use any-school treasure cards, odds published 60/30/10
- [ ] Group combat: up to 4 players join the same battle circle
- [ ] Sound: combat cast/hit/fizzle SFX + ambient city loop (Roblox Creator Store free ids)
- [ ] Mesh uploads: needs Roblox login in Chrome -> Open Cloud key -> tools/roblox_upload.py
- [ ] Animations: Tripo Animate (auto-rig) on enemy models, or Roblox pre-built emotes
- [ ] Grok images: game icon + thumbnails - needs XAI_API_KEY in .env

## Phase 2 - Ship it
- [ ] Publish to Roblox (user does first publish in Studio; then Open Cloud for updates)
- [ ] Create 4 crown Dev Products in Creator Dashboard; paste ids into CrownService.CROWN_PRODUCTS
- [ ] Real crown purchase flow: shop UI "BUY CROWNS" -> MarketplaceService:PromptProductPurchase
- [ ] Enable Studio API access for DataStores; verify saves round-trip in published game
- [ ] Private server test with 2+ accounts
- [ ] Game page: icon, thumbnails, description, genre tags

## Phase 3 - Retention & revenue (post-launch)
- [ ] Daily login rewards; first-purchase double-crowns
- [ ] Mounts (hoverboards): +40% speed, crown shop - models already exported
- [ ] Pet drones: cosmetic followers, gacha eggs - drone_pet.fbx ready
- [ ] District 5: "The Undergrid" (Lv 18-25), premium 1250 crowns
- [ ] PvP arena with ranked seasons
- [ ] Membership gamepass: all districts + daily crown stipend
- [ ] Analytics funnels: where do players quit; tune difficulty there

## Standing rules
- Never copy Wizard101 names/art/audio/maps. Mechanics only.
- Everything server-authoritative; never trust the client with currency or combat.
- Free content stays generous (Wizard City was free - that's WHY it converted).
- Keep the smoke test green; add checks for each new system.
- Every iteration ends: build relaunched in Studio with F5 + previews rendered for new assets.
