========================================================================
 RDR2 R.E.A.L. VR - "lockfree_table capacity exceeded" Popup Fix
========================================================================

Stops the "lockfree_table capacity exceeded" dialog from freezing Red
Dead Redemption 2 when playing with Luke Ross's R.E.A.L. VR mod. No more
clicking OK over and over, no more the game locking up after you change a
graphics setting.


WHAT IT DOES
------------------------------------------------------------------------
R.E.A.L. VR tracks the game's images in fixed-size tables. Two of them
only have 128 slots, and Red Dead can exceed that (especially the moment
you change a graphics/resolution setting, when it briefly holds the old
and new render targets at once). When a table fills, the mod shows a
blocking popup and then continues anyway - but because the popup freezes
rendering, they stack up and lock the game.

This fix edits YOUR OWN copy of RealVR64.dll so those popups never show;
the mod simply continues silently instead. Nothing else is changed.


REQUIREMENTS
------------------------------------------------------------------------
- Red Dead Redemption 2 (PC) with R.E.A.L. VR already installed and
  working. This does NOT include the VR mod - get that from Luke Ross.
- Windows. Nothing to install; it uses built-in PowerShell.


HOW TO INSTALL
------------------------------------------------------------------------
1. Extract this folder anywhere.
2. Double-click "Apply Fix.bat".
3. It finds your RealVR64.dll automatically (Steam / Rockstar / Epic),
   backs it up, patches it, and tells you how many popups it removed.

If it can't find the DLL, it will ask you to paste the path to
RealVR64.dll (it's in your RDR2 game folder). You can also drop this
whole folder INTO the RDR2 game folder and run it from there.


HOW TO UNINSTALL / REVERT
------------------------------------------------------------------------
Double-click "Revert Fix.bat". It restores the original DLL from the
backup (RealVR64.dll.orig_backup) made the first time you patched. You
can also just "Verify integrity of game files" on Steam.


IS IT SAFE?
------------------------------------------------------------------------
- It only edits a file you already own. It does NOT contain or share any
  R.E.A.L. VR file.
- It makes a backup first and is fully reversible.
- It is surgical: it matches the exact machine-code pattern of the
  "capacity exceeded" popup and disables only that call. If it can't find
  that pattern (a very different build), it changes nothing and says so.
- Works across RealVR builds (it scans by pattern, not fixed offsets).
- STORY MODE ONLY. Do not use mods in Red Dead Online.

No visual or performance change - you just stop getting the dialog. In
the rare case a table is genuinely full, one render target isn't tracked
for that frame (the same thing that already happened after you clicked
OK, minus the freeze).


NOTE
------------------------------------------------------------------------
This is the interim/community fix - it removes the freeze. The proper
long-term fix is raising those tables' capacity (they should be 4096,
like the mod's depth-buffer table already is), which only Luke can build
into the mod itself. Run this until/unless that ships.


CREDITS
------------------------------------------------------------------------
- R.E.A.L. VR mod - Luke Ross. This is nothing without his work; go
  support him.
- R.E.A.L. VR is built on ReShade by Patrick Mours (crosire); the
  lockfree_table structure originates there.
- Analysis & patcher - adamm0019.

Contains only the patch script and this readme. It does not redistribute
any part of R.E.A.L. VR, ReShade, or Red Dead Redemption 2. Use at your
own risk; keep the backup it creates.
