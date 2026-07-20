# RDR2 R.E.A.L. VR — "lockfree_table capacity exceeded" Popup Fix

A tiny, open-source patcher that stops the **`lockfree_table capacity exceeded`**
dialog from freezing *Red Dead Redemption 2* when playing with Luke Ross's
R.E.A.L. VR mod.

No more clicking OK over and over. No more the game locking up behind a stack of
popups after you change a graphics setting.

> **This does not contain or redistribute any R.E.A.L. VR file.** It patches the
> `RealVR64.dll` you already have installed, after making a backup. You need
> R.E.A.L. VR already working — get that from Luke Ross.

---

## Download

Grab the latest zip from **[Releases](../../releases)**, extract it anywhere, and
run **`Apply Fix.bat`**. That's it.

## What the problem is

R.E.A.L. VR tracks the game's Vulkan images in fixed-size lookup tables. Two of them — the ones holding full-resolution **colour render targets** — only have **128 slots**. Red Dead's renderer can exceed that, especially the moment you change a graphics/resolution setting, when it briefly holds the old *and* new set of render targets at once. When a table fills, the mod shows a **blocking `MessageBox`** and then continues anyway (it just skips tracking that image), but because the dialog is modal, the game stops rendering while it's up, the popups
pile on, and the game freezes.

## What this fix does

It finds those exact "capacity exceeded" `MessageBoxA` calls inside your own copy of `RealVR64.dll` and replaces each `call` with `NOP`s, so a full table continues instead of throwing a dialog.

## How it works (for the curious / the cautious)

It scans the DLL for this instruction signature (the address operands are wildcarded, so it's build-independent) and NOPs the trailing 6-byte `call`:

```
45 33 C9            xor  r9d, r9d          ; MessageBox uType = 0
4C 8D 05 ?? ?? ?? ? lea  r8, [caption]     ; "lockfree_table capacity exceeded"
48 8B D0            mov  rdx, rax          ; text
33 C9               xor  ecx, ecx          ; hWnd = 0
FF 15 ?? ?? ?? ??   call [MessageBoxA]     ; <-- replaced with 90 90 90 90 90 90
```

That signature only occurs at the mod's capacity-exceeded handlers, so nothing else in the DLL is altered. The whole patcher is a single readable PowerShell script — [`patch_realvr.ps1`](patch_realvr.ps1) — with no dependencies.

## Safety

- **Edits only a file you already own**; ships no mod files.
- **Backs up first** (`RealVR64.dll.orig_backup`) and is fully reversible.
- **Surgical & build-independent** — pattern match, not fixed offsets. If it can't
  find the pattern, it changes nothing and tells you.
- **Story mode only.** Do not use mods in Red Dead Online.

## Revert

Run **`Revert Fix.bat`** (restores the backup), or "Verify integrity of game files" on Steam.

## Credits

- **R.E.A.L. VR mod** — Luke Ross. This is nothing without his work; go support him.
- R.E.A.L. VR is built on **ReShade** by Patrick Mours (crosire); the
  `lockfree_table` structure originates there.
- **Analysis & patcher** — _adamm0019_.

## License

[MIT](LICENSE) — applies to this patcher and its docs only. R.E.A.L. VR, ReShade, and Red Dead Redemption 2 are the property of their respective owners and are not included or redistributed here.
