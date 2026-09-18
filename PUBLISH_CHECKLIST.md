# Neon Arcana — Publish Checklist (your morning to-do, choom)

Everything below is stuff only YOU can click (logins + money-adjacent). Total: ~20 minutes.
Tell Claude when each step is done and the automation takes it from there.

## 1. Roblox login in Chrome (5 min) — unlocks model uploads
- [ ] In Chrome, go to roblox.com and log in as LordGrilloGG
- [ ] Tell Claude "logged in" — Claude then creates an Open Cloud API key and uploads
      all 20 models; enemies, the Commons set, and the fountain appear in-game automatically

## 2. First publish (5 min) — makes the game real
- [ ] Open Roblox Studio with build\NeonArcana.rbxl (Claude keeps it open for you)
- [ ] File -> Publish to Roblox As... -> Create new experience
- [ ] Name: Neon Arcana  |  Genre: RPG  |  Devices: Computer + Phone + Tablet
- [ ] After publish: Game Settings -> Security -> "Enable Studio Access to API Services" = ON
      (this makes DataStores work — saves, crowns, everything persists)

## 3. Crown packs (10 min) — the money pipes
- [ ] create.roblox.com -> Creations -> Neon Arcana -> Monetization -> Developer Products
- [ ] Create these 4 products (name / price in Robux):
      - Crowns 500 / 99
      - Crowns 2250 / 399
      - Crowns 5000 / 799
      - Crowns 13500 / 1999
- [ ] Copy each product's numeric ID and paste them to Claude — they go into
      CrownService.CROWN_PRODUCTS and real purchases go live in Studio test mode

## 4. Optional same-morning
- [ ] xAI API key (console.x.ai) into .env as XAI_API_KEY= — unlocks Grok-generated
      game icon + thumbnails
- [ ] Second Roblox account or a friend for a 2-player group combat test

## What's already done while you slept
See ROADMAP.md Phase 1 — deck editor, card packs with odds, 4v4 group combat with
target selection, full sound layer, daily login rewards, hoverboard mount, win
streaks, death rules, 20 generated models, 3 animated walk cycles, 24 automated
checks green on every commit.
