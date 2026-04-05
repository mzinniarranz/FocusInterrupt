# FocusInterrupt

A World of Warcraft addon that automatically generates two macros based on your class and current specialization:

- **0FI-Kick** — Casts your interrupt at focus target, falling back to current target.
- **0FI-Mark** — Marks your mouseover target and sets it as focus.

Macros are created on login and updated automatically on spec change.

## Commands

- `/fi` or `/focusinterrupt` — Opens the settings menu.

## Settings

- Choose the raid mark used by the Mark macro (1–8).
- Refresh macros manually at any time.

## TODO

- [ ] Play a sound when focus starts casting and your interrupt is available
- [ ] Announce your assigned mark to the group

## UI

The settings UI was built entirely with vibe coding. Hats off to the people who build WoW addon UIs by hand.. that's beyond me.

## Notes

- Healers without an interrupt (Holy, Discipline, Restoration, Preservation) will not generate a Kick macro, except Restoration Shaman.
- Balance Druid uses Solar Beam instead of Skull Bash.