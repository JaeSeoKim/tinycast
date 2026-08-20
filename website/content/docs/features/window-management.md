---
title: Window management
description: 32 commands — halves, quarters, thirds, nudges, display moves and instant Space switching.
---

Move and resize the window you were last in, without installing anything else.

**It needs no new permission.** It reuses the same
[Accessibility](/docs/permissions) grant that clipboard pasting already uses.

**Settings → Window Management** holds the feature switch. It ships **off**; while off there are no
launcher entries and a still-registered shortcut moves nothing.

## The commands

**Halves** — Left · Right · Top · Bottom

**Quarters** — Top Left · Top Right · Bottom Left · Bottom Right

**Thirds** — First Third · Center Third · Last Third · First Two Thirds · Last Two Thirds

**Sizing** — Maximize · Almost Maximize · Reasonable Size · Maximize Height · Maximize Width ·
Center · Center Half · Make Larger · Make Smaller · Restore

**Moving** — Left · Right · Up · Down · Next Display · Previous Display

**Fullscreen** — Toggle Fullscreen

**Spaces** — Switch to Previous Space · Switch to Next Space

## Settings

| Setting                  | Range          | Default |
| ------------------------ | -------------- | ------- |
| Enable window management | —              | **Off** |
| Show in launcher         | —              | On      |
| Cycle sizes on repeat    | —              | **Off** |
| Gap between windows      | 0–64 pt, in 2s | **0**   |

Per-command shortcut and visibility live in this same pane — window commands deliberately get no
launcher pane of their own.

**Clearing a recorded shortcut is how you disable one.** There is no separate per-command switch.

## Geometry

**Gaps.** An edge on the screen boundary takes the full gap; an interior edge takes half. So two
adjacent tiles leave exactly `gap` between them and every screen edge is inset by `gap`. Rects round
on their edges, so thirds never overlap or leave a one-point seam.

**Make Larger / Make Smaller** step by 5% of the _screen_, not the window, forced so each edge moves
a whole point — which makes the two **exactly invertible**. The ceiling is the screen; the floor is
200×150 or 15% of the screen, whichever is larger. Both saturate into clean no-ops.

**Reasonable Size** is 60% of the screen, centred, capped at 1025×900 points — so a 5K display gets a
sensible window rather than an enormous one. It ignores the current size, making it idempotent.

**Center Half** is half the screen's _area_: half width, full height, centred.

Oversized or off-screen windows are always clamped back onto the display, pinning the leading edge.
The usable area already excludes the menu bar, the Dock and the notch.

## Cycling and Restore

**Cycling** covers the four halves only, stepping ½ → ⅓ → ⅔, and is off by default. Top and Bottom
Half cycle through vertical thirds.

It restarts at ½ when you move the window yourself (more than 2 pt), on a different command, on a
different display, after a timeout, or when cycling is off.

**Restore is single-level, not a stack.** Left Half → Maximize → Top Right → Restore lands on the
**original** frame, not the previous one.

Restore also works on windows Tinycast has never moved, because the frame is captured before the
first change. Memory is per window, capped at 64, dropped when the app quits, and never written to
disk.

## Fullscreen

**Toggle Fullscreen** uses the accessibility fullscreen attribute, falling back to pressing the
window's fullscreen button, then to a quiet no-op.

There is deliberately no synthetic <kbd>⌃</kbd><kbd>⌘</kbd><kbd>F</kbd> attempt — apps can rebind it,
and firing an unrelated menu command would be worse than doing nothing.

It clears the cycle chain but keeps the restore point.

## Spaces

**Switch to Previous Space** and **Switch to Next Space** move you to the neighbouring Space with
**no sliding transition** — the switch is there when your finger leaves the key. macOS normally
animates the slide, and its duration scales with your display's refresh rate, so the higher the
refresh rate the longer the wait.

Tinycast does not simulate <kbd>⌃</kbd><kbd>←</kbd> / <kbd>⌃</kbd><kbd>→</kbd>: that still plays the
animation, and it stops working the moment you rebind the Mission Control shortcuts. It synthesises
the trackpad's own Space swipe instead, reported as already finished, which leaves nothing to animate.

These two are the one pair that touches no window — they move **you**, not what you were last in, so
none of the geometry, cycling or restore behaviour applies. They work with regular desktop Spaces and
with full-screen apps, follow the Space order of the display you are on, and can be held down to move
several Spaces. At the first or last Space you get macOS's usual bounce, exactly as a real trackpad
swipe would give you.

## Failing quietly

Windows that are minimized, sheets or popovers, already natively fullscreen, or that report no
position or size are rejected before anything is attempted.

A non-resizable window — System Information, for instance — is left alone rather than half-moved. If
an app refuses to shrink, the window is re-placed against its anchor **once**, never in a loop.
