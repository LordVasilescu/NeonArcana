# Asset production queue

Run each with: `python tools\tripo_generate.py "<prompt>" <name>`
Style anchor for EVERY prompt: "low-poly stylized game asset, cyberpunk, neon accents, clean silhouette"

## Enemies (priority 1 — replace the glowing pads)
| name | prompt |
|------|--------|
| scrap_punk | low-poly stylized cyberpunk street punk with scrap metal armor and mohawk, game character, neon orange accents |
| wire_rat | low-poly stylized giant rat fused with cables and circuit boards, game monster, purple neon accents |
| chrome_ganger | low-poly stylized chrome-armored gang enforcer, game character, blue neon accents |
| data_wraith | low-poly stylized ghostly hooded figure made of glitching data, game monster, grey-green accents |
| sentinel_unit | low-poly stylized security robot, boxy armored, game character, blue neon accents |
| glitch_king | low-poly stylized corrupted digital king on floating throne, imposing boss, gold neon accents |

## World props (priority 2 — dress the streets)
| name | prompt |
|------|--------|
| neon_sign_1 | low-poly stylized hanging neon shop sign, kanji and circuitry, cyberpunk street prop |
| vending_machine | low-poly stylized cyberpunk vending machine, glowing front panel |
| holo_terminal | low-poly stylized holographic street terminal kiosk, cyberpunk |
| street_barrier | low-poly stylized concrete barrier with neon warning strips |

## Crown shop merch (priority 3 — the money makers)
| name | prompt |
|------|--------|
| hoverboard_basic | low-poly stylized cyberpunk hoverboard, teal neon underglow, game vehicle |
| hoverboard_flame | low-poly stylized cyberpunk hoverboard with flame decals, orange neon underglow |
| drone_pet | low-poly stylized cute companion drone, round, single glowing eye |

## Images (Grok): `python tools\grok_image.py "<prompt>" <name>`
| name | prompt |
|------|--------|
| game_icon | bold mobile game icon, cyberpunk spellcaster silhouette with neon magic cards, teal and magenta, no text |
| thumbnail_1 | roblox game thumbnail, cyberpunk street wizard duel, dramatic neon lighting, action pose |
