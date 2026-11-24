# Shard Log

Every shard you have in one Cyber Engine Tweaks window, newest first, with search and a reading pane, for Cyberpunk 2077. Single-player only.
Version 1.0.0 | For game version 2.5 | Status: runs in my game, lightly used so far; no written test record; redscript compiles and the offline mock test passes (136 of 136 checks)

**Download:** [latest release](https://github.com/penicius-code/cp2077-shard-log/releases/latest) (zip; install steps below)

> This is an unofficial fan work and is not approved/endorsed by CD PROJEKT RED. No game files are included.

## The problem

The journal's Shards screen splits shards into categories and sorts only inside each one. A shard you looted a minute ago is hard to find there, and there is no search across all of them.

## What I built

One list of every shard, sorted by when it went into the journal, with tabs, a category filter, search over titles and texts, and a reading pane. It changes: the journal's read flag of a shard you open in the window, the same as selecting it on the Shards screen. 745 lines of Lua and a 291-line redscript helper that reads the journal.

## How it works

- The redscript system reads what the Shards screen lists (the journal's onscreen entries, as the game's `CodexUtils.GetShardsDataArray` does) plus the encrypted shards in your inventory (as `ShardsMenuGameController.ProcessItem` finds them). It hands the window flat number arrays (hash, time, flags, category); titles and texts are fetched by hash only when needed.
- "Newest" uses `JournalManager.GetEntryTimestamp`, the value the Shards screen itself sorts by inside a category. A row shows the title, the category, a NEW tag on unread shards and how long ago, in game time, the shard went into the journal.
- Tabs: All, New (unread) and Encrypted, each with a count. A category filter lists only the categories you have. Search filters titles at once and the shard texts a moment after the last key press.
- Click a row: the text opens in the reading pane (beside the list when the window is 820 pixels wide or more, below it otherwise) and the shard is marked read in the journal. A button marks it unread or read again. On the New tab, a shard you just read stays listed until the overlay closes, so the list does not jump under the mouse.
- Encrypted shards are listed at the top. Their text is not shown; open them in the journal first (Shards, Encrypted), after that they show as normal shards.
- Cost: no `onUpdate`, no hooks, no keys, no wraps of game functions. Drawing stops at once while the CET overlay is closed. While it is open, one cheap change check runs every 0.5 seconds (a counter that a journal callback raises), with a full re-read after a change, on every overlay open and every 30 seconds. Only the rows inside the scroll view are drawn.

```text
package/
  bin/x64/plugins/cyber_engine_tweaks/mods/CyberslopShardLog/init.lua   the window
  r6/scripts/CyberslopShardLog/CyberslopShardLog.reds                   journal reads
tests/mock.lua    runs the Lua against a stubbed game API (136 checks)
```

Run the test from an empty folder, because it writes the mod's settings file into the current folder: `luajit <repo>/tests/mock.lua <repo>/package/bin/x64/plugins/cyber_engine_tweaks/mods/<mod folder>/init.lua`.

## Requirements

| Requirement | Version | Link |
|---|---|---|
| Cyberpunk 2077 | 2.5 | |
| Cyber Engine Tweaks | a build for 2.5 | [Nexus Mods, mod 107](https://www.nexusmods.com/cyberpunk2077/mods/107) |
| redscript | a build for 2.5 | [Nexus Mods, mod 1511](https://www.nexusmods.com/cyberpunk2077/mods/1511) |

No other mod is needed. Requirements are not bundled.

## Install

1. Install the requirements above.
2. Download the zip from the [latest release](https://github.com/penicius-code/cp2077-shard-log/releases/latest) (the same files as `package/` in this repository) and extract it into the game folder, so that `r6\scripts\CyberslopShardLog\CyberslopShardLog.reds` exists.
3. Start the game, load a save and open the CET overlay. The "Shard Log" window lists your shards. In the main menu it says "Load a save to see your shards."

## Uninstall / roll back

1. Close the game.
2. Delete `bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopShardLog\` (this also removes its `config.json`) and `r6\scripts\CyberslopShardLog\`.
3. Saves are not affected. Shards marked read in this window stay read, as if read in the journal.

## Configuration

The selected tab, sort order (newest first or A to Z) and category are remembered in `config.json` next to `init.lua`. There are no other settings.

## Status

| What | Result |
|---|---|
| In game, 1.0.0 | Runs in the author's game, lightly used so far (author's statement, 2026-11-24). No written test record. Its test list (sort order and time labels, a newly looted shard on top, read and unread in sync with the journal, search in shard texts, encrypted shards) is still open. |
| Compile | redscript compiles with 0 errors against the full installed script set; the 6 warnings are the same as without the mod. |
| Mock test | 136 of 136 checks pass with LuaJIT. The test covers the ImGui push/pop balance every frame, tabs, sort, the category list, search including the delayed text search, mark read and unread, the New tab keeping just-read shards, encrypted rows, change detection, error back-off, the main menu, a missing redscript part, a collapsed window, 407 shards and the config file. It runs in CI. |

## Compatibility

| Item | Status | Notes |
|---|---|---|
| Quest mods that check whether a shard was read | considered | There is no "mark all read" on purpose: some quest mods (for example DedraLucy Part Two) choose a branch by whether a shard was read, so only shards you open are marked. "Mark unread" on such a shard also changes what that check sees. |

## Known issues

- The journal calls follow the 2.5 game scripts; the mod has only been lightly used in game, with no written test record. If the journal callback does not fire for this kind of system, the window still re-reads on every overlay open and every 30 seconds. A failing call shows a red line in the window and one line in the mod's log; the game keeps running.

## Engineering notes

There is no recorded bug story for this mod yet; these are the design choices the code shows.

**Sorting by the journal's own time.** The Shards screen already keeps a timestamp per entry (the time of its last state change) and sorts by it inside a category. Using the same value means "newest" here agrees with the journal instead of guessing from item data.

**Few calls per refresh.** A refresh returns four number arrays instead of one object per shard, and titles are cached per shard. With 407 shards the mock measured about 42 KB of Lua garbage per full re-read and almost none per open-overlay frame.

**Re-read only after a change.** The redscript system listens to the journal's State and Visited callbacks for shard entries and raises a counter. The window polls that one number twice a second and re-reads the list only when it moved, with a 30-second fallback in case the callback never fires.

**No "mark all read".** The read flag is game state that other mods read, so the window only changes it for the shard you open, exactly as the journal does.

**Rollback.** For a user: delete two folders.

## Changelog

See [CHANGELOG.md](CHANGELOG.md). Latest: 1.0.0 (2026-11-23): first version.

## Credits and licence

Runs on Cyber Engine Tweaks and redscript, which are not included here. The window uses the same colours and row style as Quest Picker.

MIT, see [LICENSE](LICENSE). The licence covers my code only. Game names and trademarks belong to their owners.

Built with AI assistance (Claude); designed, tested and maintained by me.
