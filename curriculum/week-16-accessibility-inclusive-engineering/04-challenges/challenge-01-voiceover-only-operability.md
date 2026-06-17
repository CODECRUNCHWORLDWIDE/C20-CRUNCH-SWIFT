# Challenge 1 — Operate the whole app with the screen curtain on

**Time.** 60–120 minutes.
**Deliverable.** A short screen recording of you operating Notes v1 end to end with VoiceOver and the screen curtain on, plus an `A11Y-REPORT.md` listing every spot you got stuck and the fix, committed to your Week 16 repo. **Best on a physical device** (the curtain and the rotor are the real experience); the Simulator's VoiceOver works for a first pass.

## The premise

The automated audit finds *mechanical* failures — missing labels, small targets. It cannot tell you whether your app is actually *operable* by someone who can't see it. The only way to know that is to try: turn on VoiceOver, turn on the **screen curtain** so you genuinely have no visual information, and complete every core task. Every place you get stuck — a button VoiceOver won't focus, a control that doesn't announce its state, a flow that doesn't tell you it changed — is a bug a blind user hits too. The skill this challenge builds is *experiential*: feel your app the way a VoiceOver user does, and fix what's broken.

This is the honest test. You cannot cheat by glancing at the screen, because the screen is black.

## The setup

1. On a device: **Settings ▸ Accessibility ▸ VoiceOver ▸ On.** (Set the Accessibility Shortcut — Settings ▸ Accessibility ▸ Accessibility Shortcut ▸ VoiceOver — so a triple-click of the side button toggles it; you'll want that escape hatch.)
2. Learn the gestures (below).
3. Turn on the **screen curtain** (three-finger triple-tap — the screen goes black). Now you operate blind.

### VoiceOver gesture cheat sheet

Keep this next to you the first time — the gestures are unintuitive until they're muscle memory:

| Gesture | Action |
|---|---|
| Swipe right / left (one finger) | Move focus to next / previous element |
| Double-tap (one finger, anywhere) | Activate the focused element (the "tap") |
| Two-finger twist (rotor) | Switch navigation mode (headings, links, words, actions, containers) |
| Swipe up / down (after selecting "Actions" or "Headings" on the rotor) | Cycle actions / jump between headings |
| Three-finger swipe up / down | Scroll a page |
| Three-finger triple-tap | Toggle the **screen curtain** (screen black, VoiceOver still on) |
| Two-finger double-tap | "Magic tap" — start/stop the primary action (play/pause, answer call) |
| Two-finger Z-scrub | Dismiss / go back / escape |

The two that make or break this challenge: **the rotor's "Actions" mode** (how you reach a row's swipe actions like delete) and the **screen curtain** (the honest test). If you can't find an action, twist to "Actions" and swipe up/down on the focused element.

## The tasks — complete each with the curtain on

Run Notes v1 and complete the full core flow, *without* looking:

1. **Create a note.** Find the Add button (it should announce "Add note, button"), activate it, find the title field, type a title.
2. **Edit the body.** Move to the body field, add text. Confirm VoiceOver tells you where you are.
3. **Tag the note.** Open the tag editor, add a tag, confirm it announces the tag was added.
4. **Filter by tag.** Navigate to the tag filter, pick a tag, confirm the list announces the filtered results.
5. **Delete a note.** Find the delete action (via the row's actions rotor, per lecture 1, §6.5) and confirm it.
6. **Navigate back** to the list and confirm the note count or content changed as expected.

As you go, **note every failure** — every moment you're stuck, confused, or can't tell what happened. Common ones:

- An icon button that announces "plus" / "trash" instead of "Add note" / "Delete".
- A custom control VoiceOver reads as "image" with no button trait — you can't activate it.
- A toggle that doesn't announce its state (on/off).
- A list cell that reads as three separate fragments, tedious to navigate.
- A sheet that appears but focus stays on the list behind it (no focus move).
- A successful save with no announcement — you don't know it worked.
- Swipe-only delete with no actions-rotor equivalent — you can't delete at all.

## Fix each failure

For each one, apply the lecture-1 tools:

- Missing/wrong label → `accessibilityLabel("…")`.
- Unreachable custom control → `accessibilityAddTraits(.isButton)`.
- Missing state → `accessibilityValue("…")`.
- Fragmented cell → `accessibilityElement(children: .combine)`.
- Focus stuck behind a sheet → `@AccessibilityFocusState` to move focus on appear.
- Silent success → `UIAccessibility.post(notification: .announcement, argument: "Note saved")`.
- Swipe-only action → `accessibilityAction(named: "Delete") { … }`.

After each fix, **re-run the task with the curtain on** and confirm it's now operable.

## Document and record

1. In `A11Y-REPORT.md`, list every failure you found, the task it broke, and the fix you applied — a before/after table.
2. Record a screen capture (the device records the screen even with the curtain on; VoiceOver speech is captured too) of you completing the full flow — create, edit, tag, filter, delete — with the curtain on. This is the deliverable: proof the app is operable blind.

## Acceptance criteria

- [ ] You completed **all six core tasks** with VoiceOver and the **screen curtain** on.
- [ ] `A11Y-REPORT.md` lists every failure found (task, symptom, fix) as a before/after table — at least three real fixes.
- [ ] Each fix uses the correct modifier (label / trait / value / combine / focus / announcement / action).
- [ ] A **screen recording** shows the full flow operated with the curtain on, with VoiceOver speech audible.
- [ ] The automated audit still reports zero issues after your fixes (no regressions).
- [ ] Build with **0 warnings**.

## What "great" looks like

A weak submission says "I added some labels." A great submission says:

> Operating Notes v1 with the screen curtain on, I hit five blockers. (1) The Add button announced "plus" — relabeled "Add note". (2) The custom tag chip read as "image" and I couldn't remove a tag — added `.isButton` and an "Remove tag" action. (3) Creating a note gave no feedback — added an `.announcement` "Note created". (4) The edit sheet appeared but focus stayed on the list — added `@AccessibilityFocusState` to land focus on the title field. (5) Delete was swipe-only and unreachable — exposed it via `accessibilityAction(named: "Delete")` in the row's rotor. After the fixes I completed create → edit → tag → filter → delete entirely blind; the recording is `voiceover-flow.mov`. The audit still reports zero issues.

Specific blockers, specific fixes, and a recording that proves it. That's the senior-engineer answer — and the most convincing accessibility artifact you can put in a portfolio.

## Where this reappears

The "operate it blind" instinct is the real accessibility bar — the one App Review, enterprise procurement, and accessibility law actually hold you to, beyond the automated audit. And the focus-management and announcement tools you used here are the same ones that make your app work with Voice Control and, in Phase IV, with Siri and App Intents — a well-described, well-orchestrated app is legible to every assistive and automation technology, not just VoiceOver.
