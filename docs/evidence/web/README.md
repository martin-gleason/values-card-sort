# Accessibility evidence — web port (`Web/F1`)

WCAG 2.2 AA, no exemptions. The web analogue of `D5`.

Regenerate:

```
node scripts/check_web_a11y.js --evidence docs/evidence/web
```

## Result

Verbatim output of the command above. **Nothing is trimmed.**

```
Accessibility gate — WCAG 2.2 AA, no exemptions (the web D5)

  ok   1-sort @desktop                 24 rules passed
  ok   1-sort @narrow                  24 rules passed
  ok   2-sort-add-card @desktop        25 rules passed
  ok   2-sort-add-card @narrow         25 rules passed
  ok   3-sort-complete @desktop        22 rules passed
  ok   3-sort-complete @narrow         22 rules passed
  ok   4-cull @desktop                 24 rules passed
  ok   4-cull @narrow                  24 rules passed
  ok   5-cull-promote @desktop         24 rules passed
  ok   5-cull-promote @narrow          24 rules passed
  ok   6-rank @desktop                 24 rules passed
  ok   6-rank @narrow                  24 rules passed
  ok   7-export @desktop               25 rules passed
  ok   7-export @narrow                25 rules passed
  ok   9-rank-unbreakable-name @desktop  24 rules passed
  ok   9-rank-unbreakable-name @narrow  24 rules passed
  ok   8-reset-dialog @desktop         15 rules passed
  ok   8-reset-dialog @narrow          15 rules passed

Evidence written to docs/evidence/web/

PASSED — 0 failures across 9 states x 2 viewports (WCAG 2.2 AA, Reduce Motion on).
```

Tags run: `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`. No rule is
disabled. Every state is audited at **1024px and 320px** with
**Reduce Motion emulated**, and horizontal overflow is asserted at both widths
(WCAG 1.4.10). `axe-report.json` carries the machine-readable run.

> **An earlier version of this file was not honest.** The block above used to be
> hand-written: it dropped the `[needs review: color-contrast]` suffixes and
> around thirty `?` detail lines, so it read clean when the real output was not.
> `axe-report.json` was accurate throughout; the transcript above it was not.
> In a repository whose baseline says *assertions are not evidence*, a doctored
> transcript is worse than none, and it is recorded here rather than quietly
> replaced.

Full-page captures of each audited state, at 2x device pixel ratio:

| State | Capture |
|---|---|
| Sort — a card on the desk | `1-sort.png` |
| Sort — write your own card (R4) | `2-sort-add-card.png` |
| Sort — queue-empty interstitial | `3-sort-complete.png` |
| Cull — choose 5 to 10 (R5) | `4-cull.png` |
| Cull — promotion offered (R6) | `5-cull-promote.png` |
| Rank — order the kept values (R7) | `6-rank.png` |
| Export — results, markdown, downloads (R8) | `7-export.png` |
| Export — start-over confirmation (R9) | `8-reset-dialog.png` |
| Rank — a written card with a long unbroken name (R4 + 1.4.10) | `9-rank-unbreakable-name.png` |

**Eight states, not four screens.** The two transient states — the
write-your-own-card form and the start-over confirmation — are audited too. A
gate that only ever sees the first screen is not a gate.

## What axe could not decide, and what it turned out to be

axe reports `color-contrast` as **incomplete** rather than failing it when it
cannot resolve a background. Incomplete is not a pass, and under `D5` it cannot
be shrugged off, so every case was computed by hand. **One of them was a real
defect that the automated gate could not see.**

**The gate now fails on any incomplete it does not recognise.** Each row below
is registered in `REVIEWED_INCOMPLETE` in `scripts/check_web_a11y.js` with the
hand-computed ratio; anything else stops the build until someone measures it.
The first version counted only `violations`, so a new contrast defect over the
ruled gradient would have printed `PASSED` — the same hole that hid the 3.34:1
failure, still open in the tool that found it.

| Where | Why axe declined | Worst case | Verdict |
|---|---|---|---|
| `#card-name`, `#card-desc` on the card face | text sits over the ruled `repeating-linear-gradient` | `--ink` on `--rule` `#C9DEE9` = **9.62:1** | pass |
| `.card-desc` on the export card | same gradient | as above | pass |
| accent numerals on the export card | same gradient | `--accent` `#C34F45` on `#C9DEE9` = **3.34:1** | **FAILED — fixed** |
| `.move` rank buttons (▲ ▼) | "content contains only non-text characters" | `--ink` on `#FFF` = **13.36:1** | pass |
| `#reset-dialog > p` | element overlaps the `::backdrop` | `--ink` on `--paper` = **13.00:1** | pass |

### The defect the gate could not catch

The rank numerals on the export card are accent-coloured and sit on the same
ruled gradient as the text. On a paper band they are 4.52:1; **where they cross
a blue rule they fall to 3.34:1**, under the 4.5:1 they owe. axe returned
`incomplete` for exactly these nodes, so a run read as "0 violations" while the
page had a real contrast failure in it.

Fixed by adding `--accent-ink: #A04139`, used wherever accent appears as *text*:
4.56:1 on the rule, 6.17:1 on the paper band, 6.34:1 under white. Fills keep
`--accent`.

This is the argument for not treating `incomplete` as noise.

## Palette corrections carried from the reference

`reference/valuescardsort.jsx`'s colours were measured before being ported, and
five failed. The corrections are the smallest that clear the threshold, so the
card face still looks like the reference's index card.

| Token | Reference | Ratio | Corrected | Ratio |
|---|---|---|---|---|
| primary button, white text | `#C75146` | 4.47:1 | `#C34F45` | 4.64:1 |
| accent text on paper | `#C75146` | 4.35:1 | `#C34F45` | 4.52:1 |
| accent text on the ruled card | — | 3.34:1 | `#A04139` | 4.56:1 |
| progress fill on the desk (1.4.11) | `#C75146` | 2.78:1 | `#D1554A` | 3.03:1 |
| attribution line | `rgba(255,255,255,.45)` | 3.84:1 | `--muted #9BB4A9` | 5.63:1 |
| keyboard hint | `rgba(255,255,255,.35)` | 2.91:1 | `--muted #9BB4A9` | 5.63:1 |

`--rule` (`#C9DEE9`, 1.35:1) and `--redrule` (`#DB9A93`, 2.26:1) are left exactly
as the reference has them. **That is not an exemption.** They are the printed
lines of an index card and carry no information; WCAG 1.4.11 scopes to graphics
needed to understand content or identify a control, and they are neither.
Darkening them to clear a threshold that does not apply would wreck the card
face and buy no one anything.

## Not covered here

- **Screen-reader transcripts.** The page announces card changes, sort results,
  cull tallies and rank moves through one polite live region, and every control
  carries an accessible name that includes the card it acts on. axe checks that
  names exist; it cannot judge whether the announcements are *useful*. A manual
  VoiceOver and NVDA pass is still owed.
- **Print output** differs by browser. The stylesheet is written and the full
  sort renders as real text rather than a screenshot, but page-break behaviour
  in Safari, Chrome and Firefox has not been compared.

## Keyboard-only traversal

`node scripts/check_web_keyboard.js` — a complete sort driven with trusted key
events and **no pointer at all**. axe never presses a key, so it cannot tell you
whether the instrument can be *completed* without a mouse; this can.

```
  ok   R11 pressing 3 sorts the card into Important to me
  ok   R11 keys 1-5 each reach their own pile
  ok   R11 pressing U undoes the last placement
  ok   opening the form moves focus into the name field
  ok   R4 a card can be written with the keyboard alone
  ok   digits typed into the form did not sort anything
  ok   the whole deck sorts by keypress alone
  ok   R5 cards can be cut by keyboard
  ok   R7 the ranking can be reordered by keyboard
  ok   focus survives the re-render after a rank move
  ok   R8 export is reached by keyboard alone
  ok   R9 Escape dismisses the dialog without destroying the sort

PASSED — all 25 keyboard checks, no pointer used.
```

The first run of this reported six failures. All six were defects in the test
harness, not the page: its tab-search built `return (predicate)` instead of
calling the predicate, so it matched the first focusable element every time —
the skip link — and pressing Enter jumped focus to `#main`. Worth recording,
because the failure looked exactly like a real focus-management bug and was
confirmed as a harness fault only by tracing focus through a real keypress.
