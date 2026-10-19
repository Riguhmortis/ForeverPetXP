# Forever Pet XP

A small, movable experience and happiness display for Hunter pets in **World of Warcraft: Forever**.

Targets the **1.60.1** Forever client, interface **16001**. Version **0.2.0** passes 47 automated Lua 5.1 behavior checks; its new happiness display, audio, and controls still need an in-game check. Version **0.1.0** was confirmed working in-game on build **1.60.1.70009**.

## Features

- Pet name, level, current XP, required XP, and percentage.
- Happiness meter: red **Unhappy**, yellow **Content**, or green **Happy**, with the damage modifier reported by the game.
- Floating happiness gains such as **+59 Happiness** when readable amounts are available; **Feeding pet** feedback when a Feed Pet cast or effect is detected.
- Animal sounds when happiness rises from red to yellow or yellow to green; a short **womp womp** when it drops into red. Toggle both with `/petxp sound`.
- Click the color square to adjust the outline with live red, green, and blue sliders, saved per character.
- Click **X** to hide the addon on any character, including non-Hunters. `/petxp show` restores it; existing locked/no-pet visibility rules still apply.
- Reads the same `GetPetExperience()` values as the character sheet pet bar, even when the character sheet is closed.
- Updates on pet XP events, pet swaps, level changes, and a one-second fallback refresh.
- Left-drag to move; saved position, size, visibility, and lock state for each character.
- Right-click to open Character > Pet when out of combat.
- Tooltip with XP remaining until the next pet level.
- When locked, hides automatically with no summoned pet or on non-Hunter characters.
- No dependencies, bundled libraries, or changes to Blizzard's original XP bar.

## Install

Stable packages are available from the [latest release](https://github.com/Riguhmortis/ForeverPetXP/releases/latest). Check the version shown there: a source update does not automatically publish a new release ZIP. To try 0.2.0 before a release is published, download the source ZIP from the branch containing this update and follow the source ZIP instructions below.

1. Exit WoW completely before installing a new addon.
2. Extract the release ZIP.
3. Copy the **ForeverPetXP** folder into your Forever client's `Interface/AddOns` folder. The current beta normally uses `World of Warcraft/_classic_beta_/Interface/AddOns`.
4. Verify the result is `Interface/AddOns/ForeverPetXP/ForeverPetXP.toc`. Avoid a second nested `ForeverPetXP` folder.
5. Launch Forever, enable **Forever Pet XP** in the AddOns list, and log in to your Hunter.
6. Summon your pet. Drag the bar into place, then type `/petxp lock`.

The bar initially appears unlocked near the lower middle of the screen. If there is no pet, it displays a positioning placeholder. `/petxp reset` restores it if you lose track of it.

When installing from a GitHub source ZIP, rename the extracted repository folder to **ForeverPetXP** before placing it in AddOns. The `.toc` and `.lua` files must be directly inside that folder.

## Controls

| Action | Command or gesture |
| --- | --- |
| Move the bar | Left-drag while unlocked |
| Open the pet sheet | Right-click, or `/petxp pet` |
| Lock position | `/petxp lock` |
| Unlock and show | `/petxp unlock` |
| Change size | `/petxp scale 1.2` (0.6–2) |
| Change width | `/petxp width 360` (240–700) |
| Hide / show | `/petxp hide` / `/petxp show` |
| Hide with the mouse | Click **X** in the top-right corner |
| Change outline color | Click the color square, or `/petxp color` |
| Toggle all happiness sounds | `/petxp sound` (or `/petxp sound on` / `off`) |
| Preview your pet's animal sound | `/petxp sound test` |
| Preview the red-happiness sound | `/petxp sound test red` |
| Reset settings | `/petxp reset` |
| Toggle sample preview | `/petxp test` |
| Help | `/petxp` |

`/fpetxp` is an alias if another addon already uses `/petxp`.

Preview data is explicitly labeled and is never saved as real pet XP or happiness. `/petxp test` also shows a sample **+59 Happiness (preview)** popup. Preview mode ends on reload. A pet at your level may stop gaining XP until you level. When the client reports zero required XP and the pet is at your level, the bar says **Pet is at your level**. Missing or restricted data displays **Pet XP unavailable**, not a guessed percentage.

## Happiness and feeding

The lower meter uses Forever's `C_PetInfo.GetPetHappiness()`. When exact, public happiness points are available through `UnitPower` and `UnitPowerMax`, its fill follows those points and the tooltip includes the numbers. Otherwise it shows the three mood levels (one-third, two-thirds, or full); this is a mood indicator, **not an estimated percentage of happiness**. Missing mood data is labeled **Happiness unavailable**.

Positive changes in readable happiness points produce a floating gain popup. A public happiness energize event from the combat log is a fallback when point totals are unavailable. Gains are filtered to the active pet, exclude reported overflow, and are not calculated across pet swaps, reloads, or hidden periods. The amount is game data; **59 is only an example**, except in the explicitly labeled preview.

Forever can restrict numerical happiness, pet identity, auras, or combat-log access. In that case the addon keeps the readable mood display and shows **Feeding pet** when it can detect the successful Feed Pet cast or its effect. It does not invent a numeric gain or bypass restricted data. Food quality, interrupted feeding, and the happiness cap can affect actual gains. These paths require live testing on your particular beta build.

The outline color stays the same when locked. Existing position, scale, width, and visibility settings are preserved on upgrade. **X** saves visibility only for the current character, so hiding a Mage's display does not hide your Hunter's display.

## Happiness sounds

Sounds are on by default and saved per character. They use the **Effects (SFX)** channel and respect your game's volume and mute settings.

| Change | Sound |
| --- | --- |
| Red → yellow | Animal clip matched to the current pet family |
| Yellow → green | Animal clip matched to the current pet family |
| Yellow or green → red | Bundled 1.85-second **womp womp** |
| Green → yellow | Silent |
| Feeding starts, individual point gains, or repeated events in the same mood | Silent |
| Login, summon, pet switch, re-show, or sample preview | Silent |

If the client skips an intermediate mood, an observed red → green jump plays one animal clip. An unavailable mood resets the comparison; restoring data does not fabricate a transition. `/petxp sound test` and `/petxp sound test red` are explicit sound previews and require a summoned Hunter pet and enabled sounds.

There are profiles for 19 animal families, including wolves, cats, bears, boars, bats, birds, hyenas, reptiles, spiders, scorpids, core hounds, and foxes. Family names are matched using the client's localized creature-family information, with English names as a fallback. Unknown families or unavailable built-in animal clips use a generic eating sound. See [SOUNDS.md](SOUNDS.md) for the exact mapping and asset provenance. Built-in clips are referenced by FileDataID; the small original womp-womp OGG is included in `Sounds/` and must be installed with the Lua and TOC files.

## Compatibility and testing

This targets the modern Forever beta client, not the original 1.12 client or retail WoW. It uses the build's real `UNIT_PET_EXPERIENCE` event and its PaperDoll pet sidebar.

Source references for build 1.60.1.70009:

- [Blizzard UI source mirror: pet XP bar](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_StatusTrackingBar/Camelot/PetExpBar.lua)
- [Blizzard UI source mirror: character sheet](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua)

Happiness integration references inspected at UI-source commit `172a387e3ab85b26e6640d3058d5ec1e6ccd4c63`:

- [Blizzard happiness indicator and mood API](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_FrameXML/PetHappiness.lua)
- [Power types: Forever Happiness is 27, not Classic's old 4](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_APIDocumentationGenerated/PowerTypeConstantsDocumentation.lua)
- [Public aura lookup documentation](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
- [Combat log energize payload](https://github.com/Gethe/wow-ui-source/blob/172a387e3ab85b26e6640d3058d5ec1e6ccd4c63/Interface/AddOns/Blizzard_CombatLogProcessor/Blizzard_CombatLogProcessor.lua)

The initial version was confirmed working in-game on September 28, 2026. For future changes and beta patches, use this regression checklist:

1. Compare exact XP values with Character > Pet, then close the sheet and earn pet XP.
2. Move and lock the bar; `/reload` and confirm its position and lock state persist.
3. Dismiss, summon, revive, rename, and switch pets; confirm the display follows the active pet.
4. Confirm a level-up updates the XP requirement, and a pet at your level is represented accurately.
5. Right-click the bar outside combat and confirm it opens the pet sheet. During combat the shortcut asks you to wait.
6. Try a different UI scale and resolution; confirm the bar stays accessible.
7. Compare happiness and damage with Blizzard's pet happiness indicator. Feed different foods and check the actual tick popups, or the **Feeding pet** fallback when amounts are restricted. Interrupt feeding and try feeding at the happiness cap.
8. Move each color slider, lock the bar, and `/reload`; check that the chosen outline persists. Confirm the labels fit at widths 240 and 300 and scales 0.6, 1, and 2.
9. Click **X** on a non-Hunter, `/reload`, and confirm it stays hidden. Restore with `/petxp show`; log into your Hunter and confirm that character's visibility was unaffected.
10. Try `/petxp sound test` and `/petxp sound test red`. Confirm animal audio on red → yellow and yellow → green, womp womp only on entering red, and silence on green → yellow and repeated feeding ticks. Check `/petxp sound off`, `/reload`, and game SFX mute.

Beta patches may change APIs or the interface number. Please include your game build, what you were doing, and any Lua error when reporting a problem.

### Automated checks

With Python available, install the optional test dependency using `python -m pip install lupa`, then run `python tests/run.py`. The tests use Lua 5.1 and a simulated WoW environment to check XP changes, happiness moods and amounts, feeding popups, sound triggers/toggles/family selection, pet swaps, restricted/missing data, color migration/persistence, close/restore behavior, and the panel shortcut. These checks do not verify rendering, audible playback, or protected-action behavior in the game.

## Contributing and license

Suggestions, [bug reports](https://github.com/Riguhmortis/ForeverPetXP/issues), and pull requests are welcome. Keep changes focused on pet experience and happiness and avoid protected combat actions.

Licensed under the [MIT License](LICENSE). You may use, share, and modify this addon.
