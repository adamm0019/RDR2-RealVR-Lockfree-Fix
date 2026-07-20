# R.E.A.L. VR (RealVR64.dll) — "lockfree_table capacity exceeded" root-cause analysis

**Author:** prepared for Luke Ross from static reverse-engineering of a shipped build.
**Binary:** `RealVR64.dll`, version string `5.0.2.6629`, built 2022-06-19, SHA-256
`11883a373630cddebd14c04f3fa3dc343c6cfcf8a1abd3e3b1b066a5e208ece3`.
**Game:** Red Dead Redemption 2, Vulkan, build 1.0.1491.50 (logged as "Unsupported game version" but playable).
**Host:** AMD RX 7800 XT, Meta Quest 3. Popup reproduces on startup and, reliably, after changing in-game graphics settings.

All addresses below are default-image-base VAs (`ImageBase = 0x180000000`). File offsets given where relevant.

---

## TL;DR

The dialog is thrown by the **full-table handler of a `lockfree_table<VkImage_T*, VkImageCreateInfo, 128>`** — one of the *color render-target* trackers, not the depth tracker. The create/destroy paths are symmetric (erase exists and is reached), so this is **capacity exhaustion, not a missing-erase bug**: RDR2's live full-resolution color-RT working set — and especially the transient spike when the engine reallocates render targets on a settings/resolution change (old set + new set momentarily coexist, both matching the size/format predicate and both tracked) — exceeds **128** live entries.

**Recommended fix:** raise these two color-RT tables' capacity from `128` to `4096` (i.e. match the depth-buffer table you already ship at 4096). This also flips the template onto its hashed start-index fast path (`MAX_ENTRIES > 512`), so per-image create/destroy stops being an O(128) linear scan. A binary patch is **not** viable (the per-table counter offset `base+0x800` is hard-baked and BSS spacing is tight) — it's a one-line-per-table source change + recompile.

---

## The three tables

All are `lockfree_table<VkImage_T*, VkImageCreateInfo, N>` (RTTI type descriptors present in the binary — `$0IA@` = 0x80 = 128, `$0BAAA@` = 0x1000 = 4096). Value type is heap-allocated, so each slot is 16 bytes `{ std::atomic<VkImage*> key; VkImageCreateInfo* value; }`, followed by a 4-byte live-count at `base + N*16`.

| Purpose | Capacity | Storage base (VA) | Count @ | Notes |
|---|---|---|---|---|
| Depth/stencil tracker | 4096 | `0x180dcd420` | `0x180ddd420` | hashed start index (`& 0x7ff`) |
| Color-RT tracker A | **128** | `0x180d7b2c0` | `0x180d7bac0` | linear scan from 0 |
| Color-RT tracker B | **128** | `0x180dbcc00` | `0x180dbd400` | linear scan from 0 |

The two 128 tables partition tracked color targets by a size class (the create hook compares extent against the game's render dims and fixed sizes 0x80/0x100/0x200/0x400). Both overflow the same way; the user's dialog printed the `...,128,...` type.

---

## Insert path — `hook_vkCreateImage` @ `0x1801b6320`

1. Calls the real `vkCreateImage` via the device dispatch table (`call [device+0x140]`).
2. On `VK_SUCCESS`, routes on `createInfo->format` (`+0x18`):
   - **format ∈ 0x7c..0x82** (`VK_FORMAT_D16_UNORM` .. `D32_SFLOAT_S8_UINT`) → inline emplace into the **4096 depth** table (`0x1801b6788`, hashed).
   - **else**, gated on mode flag `[0x1804f95e0] == 1` **and** `mipLevels==1 && arrayLayers==1 && samples==1` **and** extent matching the game backbuffer / eye dims (plus specific color formats incl. `0x61 = VK_FORMAT_R16G16B16A16_SFLOAT`) → emplace into one of the two **128** color-RT tables via helper below.
3. **Emplace helper @ `0x1801beb60`** (`lockfree_linear_map::emplace`): `new VkImageCreateInfo` (0x58 bytes), then linear scan slots `0..128` for an empty key, CAS `0 → update_value`, publish. On **full** → `operator delete` the value, then:
   - `MessageBoxA(NULL, <demangled type name>, "lockfree_table capacity exceeded", MB_OK)` at **`0x1801bec15`**,
   - then returns the shared `thread_local` `default_value()` and continues.

The `MessageBoxA` (USER32) call and the "return default and carry on" fall-through are why dismissing the box lets the game proceed — the popup is cosmetic, but **modal**, so while it's up RDR2 stops presenting and (before `AutokillOnFreeze=0`) the mod's own freeze-watchdog would terminate the process.

> Note: stock ReShade's full-table branch is a silent `assert(false)`. The `MessageBoxA "lockfree_table capacity exceeded"` handler is a fork-local modification (there are 23 inlined copies across all table instantiations; the two that name these image tables are `0x1801bec15` → 128 table, `0x1801b692c` → 4096 table).

## Erase path — `hook_vkDestroyImage` @ `0x1801b6970`

Erases the image key from **all three** tables (depth 4096 hashed, then both 128 color tables linear), each freeing the heap `VkImageCreateInfo` and decrementing the live-count, then tail-calls the real `vkDestroyImage` (`jmp [device+0x148]`). The two 128-table erases are gated on the **same** `[0x1804f95e0]==1`. So insert and erase are symmetric.

## Why it isn't a gating leak

`0x1804f95e0` is a **mode selector set once at init** — 9 stores of constants `1..8` and `13` in a single config function (`0x18009547a`–`0x180095cf9`), never written per-frame. Image tracking is active whenever it's `1`; it doesn't toggle mid-session, so destroys aren't being silently skipped. That leaves genuine capacity exhaustion (live working set + realloc spike) as the cause — consistent with the popup appearing on graphics-settings changes.

---

## Recommended fix (source)

Change the capacity of the two color render-target `lockfree_table<VkImage, VkImageCreateInfo, 128>` members to **4096** (match the depth table). Benefits:

- Ample headroom for RDR2's full-res color-RT set and the reallocation spike on settings/resolution changes.
- `MAX_ENTRIES > 512` auto-selects the hashed start-index path in `at()/emplace()/erase()`, so per-image create/destroy is no longer an O(128) linear probe.
- No other edits: recompilation regenerates the `base + N*16` live-count offset and the backing storage size correctly.

If you'd rather not pay the (small) extra static footprint, 1024 or 2048 would also comfortably clear the observed spike and still enable the hashed path.

(Optional hardening, not required given the above: the modal `MessageBoxA` on a full table is a poor failure mode for a shipped build — a rate-limited log line or a silent drop degrades far more gracefully than a dialog that stalls presentation.)

---

## Interim hotfix the user is running now

Because the counter offset is hard-baked, capacity can't be safely bumped in the binary. Instead the two `MessageBoxA` calls are NOP'd so a full table degrades silently (returns `default_value`, continues — an untracked RT just isn't intercepted that frame):

| VA | file offset | before | after |
|---|---|---|---|
| `0x1801bec15` | `0x1be015` | `ff 15 35 3b 1f 00` | `90 90 90 90 90 90` |
| `0x1801b692c` | `0x1b5d2c` | `ff 15 1e be 1f 00` | `90 90 90 90 90 90` |

Original DLL preserved next to it as `RealVR64.dll.orig_backup`. This is a stopgap for playability only; the capacity increase above is the actual fix.
