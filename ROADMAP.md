# Neon Arcana â€” Development Roadmap

Work top to bottom. Every item: implement -> stylua/selene -> rojo build -> run-in-roblox
smoke test -> commit. Add smoke checks for new systems as they land.

## Phase 1 â€” Wizard City parity (CURRENT)
- [x] 7 schools, 35 spells, school selection
- [x] 4 districts + hub, quest chain, 8 enemy types, 2 bosses
- [x] XP/levels, credits, crowns, premium gate (Mainframe Blvd)
- [x] Night city: skyline, lamps, fog
- [x] Gear system: visor/jacket/boots stat items (health, accuracy, power chance), enemy drops, auto-equip upgrades
- [x] Side quests: 7 street jobs via Fixer NPCs at every street mouth, parallel tracking
- [ ] Deck editor UI: choose which owned cards go in your deck (W101's deckbuilding)
- [ ] Card packs in shop: 100 crowns/pack, random card cosmetic variants (SHOW ODDS â€” Roblox rule)
- [ ] Group combat: up to 4 players join the same battle circle (CombatService already takes N combatants)
- [x] Treasure chests: data caches in all streets + plaza, credits + gear rolls, cooldowns
- [x] Boss drops: Glitch Crown / Overseer Halo guaranteed (chance=1 drop tables)
- [ ] Sound: combat cast/hit/fizzle SFX + ambient city loop (Roblox Creator Store free assets)
- [ ] Tripo assets: replace enemy pads with real models (see assets/ASSET_LIST.md) â€” needs TRIPO_API_KEY in .env
- [ ] Grok images: game icon + thumbnails â€” needs XAI_API_KEY in .env

## Phase 2 â€” Ship it
- [ ] Publish to Roblox (user does first publish in Studio; then rojo/Open Cloud for updates)
- [ ] Create 4 crown Dev Products in Creator Dashboard; paste ids into CrownService.CROWN_PRODUCTS
- [ ] Real crown purchase flow: shop UI "BUY CROWNS" -> MarketplaceService:PromptProductPurchase
- [ ] Enable Studio API access for DataStores; verify saves round-trip in published game
- [ ] Private server test with 2+ accounts
- [ ] Game page: icon, thumbnails, description, genre tags

## Phase 3 â€” Retention & revenue (post-launch)
- [ ] Daily login rewards; first-purchase double-crowns
- [ ] Mounts (hoverboards): +40% speed, crown shop, Tripo models
- [ ] Pet drones: cosmetic followers, gacha eggs
- [ ] District 5: "The Undergrid" (Lv 18-25), premium 1250 crowns
- [ ] PvP arena with ranked seasons
- [ ] Membership gamepass: all districts + daily crown stipend
- [ ] Analytics funnels: where do players quit; tune difficulty there

## Standing rules
- Never copy Wizard101 names/art/audio/maps. Mechanics only.
- Everything server-authoritative; never trust the client with currency or combat.
- Free content stays generous (Wizard City was free â€” that's WHY it converted).
- Keep the smoke test green; add checks for each new system.
