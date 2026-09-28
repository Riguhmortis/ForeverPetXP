# Forever Pet XP

A small, movable experience bar for Hunter pets in **World of Warcraft: Forever**.

Built for **1.60.1.70009**, interface **16001**. Version **0.1.0** has been confirmed working in-game by its user and passes 21 automated Lua 5.1 behavior checks.

## Features

- Pet name, level, current XP, required XP, and percentage.
- Reads the same `GetPetExperience()` values as the character sheet pet bar, even when the character sheet is closed.
- Updates on pet XP events, pet swaps, level changes, and a one-second fallback refresh.
- Left-drag to move; saved position, size, visibility, and lock state for each character.
- Right-click to open Character > Pet when out of combat.
- Tooltip with XP remaining until the next pet level.
- When locked, hides automatically with no summoned pet or on non-Hunter characters.
- No dependencies, bundled libraries, or changes to Blizzard's original XP bar.

## Install

Download the installable **ForeverPetXP-0.1.0.zip** from the [latest release](https://github.com/Riguhmortis/ForeverPetXP/releases/latest).

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
| Reset settings | `/petxp reset` |
| Toggle sample preview | `/petxp test` |
| Help | `/petxp` |

`/fpetxp` is an alias if another addon already uses `/petxp`.

Preview data is explicitly labeled and is never saved as real pet XP. Preview mode ends on reload. A pet at your level may stop gaining XP until you level. When the client reports zero required XP and the pet is at your level, the bar says **Pet is at your level**. Missing or restricted data displays **Pet XP unavailable**, not a guessed percentage.

## Compatibility and testing

This targets the modern Forever beta client, not the original 1.12 client or retail WoW. It uses the build's real `UNIT_PET_EXPERIENCE` event and its PaperDoll pet sidebar.

Source references for build 1.60.1.70009:

- [Blizzard UI source mirror: pet XP bar](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_StatusTrackingBar/Camelot/PetExpBar.lua)
- [Blizzard UI source mirror: character sheet](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua)

The initial version was confirmed working in-game on September 28, 2026. For future changes and beta patches, use this regression checklist:

1. Compare exact XP values with Character > Pet, then close the sheet and earn pet XP.
2. Move and lock the bar; `/reload` and confirm its position and lock state persist.
3. Dismiss, summon, revive, rename, and switch pets; confirm the display follows the active pet.
4. Confirm a level-up updates the XP requirement, and a pet at your level is represented accurately.
5. Right-click the bar outside combat and confirm it opens the pet sheet. During combat the shortcut asks you to wait.
6. Try a different UI scale and resolution; confirm the bar stays accessible.

Beta patches may change APIs or the interface number. Please include your game build, what you were doing, and any Lua error when reporting a problem.

### Automated checks

With Python available, install the optional test dependency using `python -m pip install lupa`, then run `python tests/run.py`. The tests use Lua 5.1 and a simulated WoW environment to check XP changes, pet swaps, missing data, settings, and the panel shortcut. These checks do not verify rendering or protected-action behavior in the game.

## Contributing and license

Suggestions, [bug reports](https://github.com/Riguhmortis/ForeverPetXP/issues), and pull requests are welcome. Keep changes focused on pet experience and avoid protected combat actions.

Licensed under the [MIT License](LICENSE). You may use, share, and modify this addon.
