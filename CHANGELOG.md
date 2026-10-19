# Changelog

## 0.2.0 — 2026-10-19

- Add a happiness meter below XP, using Forever's mood API and public point totals when available.
- Add floating happiness gains from readable power changes or public combat-log events; detect Feed Pet casts/effects for a nonnumeric fallback when amounts are restricted.
- Play an animal-family clip on red → yellow and yellow → green, and an original bundled womp-womp clip on entering red. Keep green → yellow and individual feeding ticks silent. Add `/petxp sound`, `on`, `off`, `test`, and `test red` with a saved per-character toggle.
- Add a color square and `/petxp color` to open live RGB outline sliders. Save colors per character and preserve them while locked.
- Add an X button that hides the display for the current character, including non-Hunters. Restore with `/petxp show`.
- Extend `/petxp test` with sample happiness and a clearly labeled +59 popup.
- Preserve existing saved settings and migrate missing/invalid color settings safely.

All 47 automated Lua 5.1 behavior checks pass. The user confirmed version 0.2.0 works in-game on October 19, 2026. Numeric feeding gains depend on the client exposing readable data; no estimated amounts are shown.

## 0.1.0 — 2026-09-28

Initial public release for WoW: Forever 1.60.1.70009. Adds movable pet XP tracking, saved settings per character, size controls, locking, a pet sheet shortcut, and a labeled sample preview.

The user confirmed the addon works in-game. All 21 automated Lua 5.1 behavior checks passed. Future beta builds may require compatibility updates.
