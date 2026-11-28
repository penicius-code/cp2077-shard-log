# Changelog

For game version 2.5.

## 1.1.0 - 2026-11-25
### Added
- Shard audio, when Shard Audio Framework and AudioXL are installed: rows of shards that have a recording carry an AUDIO tag; the reading pane has PLAY AUDIO / STOP AUDIO; while a recording plays, the bottom line shows its title and position with a STOP button. Playback continues while you browse or close the window.
- A recording started from the journal button is stopped first, and the framework's own state is kept in step, so its journal button, phone messages and "stop on phone call" act on the recording started here.
- The audio code is behind `@if(ModuleExists("AudioXL"))`: without AudioXL the mod compiles and shows no audio buttons.

Not run in game yet. Mock test: 196 of 196.

## 1.0.0 - 2026-11-23
- First version: every shard in one window, newest first, with All / New / Encrypted tabs, a category filter, search over titles and texts, a reading pane, and mark read / unread.

Runs in the author's game, lightly used so far; no written test record. redscript compiles (0 errors). Mock test: 136 of 136.
