# Proposed spec deltas

Working doc. `docs/SPEC.md` is the ratified contract and the agent never edits
it on its own authority (CLAUDE.md). Everything here is a **proposal** until
Marty says yes; ratified items move into SPEC.md and `docs/decisions.md` and
are struck from this file.

Status legend: **Ratified** (verbally, in session — awaiting transcription into
SPEC.md) · **Proposed** (needs a yes) · **Withdrawn**.

---

## D1 — O1: minimum OS versions · **Ratified 2026-08-14**

iOS/iPadOS **18.0**, macOS **15.0**, built against the Xcode 26 / iOS 26 SDK.

Closes SPEC §11 O1 as proposed. Implemented in `project.yml` and
`Package.swift`. Nothing in F1–F10 needs a newer API, and a free self-help tool
should not exclude anyone still on last year's OS.

**SPEC edit:** §3 "Proposed minimums (ratify)" → "Minimums (ratified
2026-08-14)". §11 — strike O1.

---

## D2 — O2: `#AI/Claude` in the export footer · **Ratified 2026-08-14**

**Dropped** from the public build.

Closes SPEC §11 O2 as proposed. It is Marty's personal filing convention and
has no business in a stranger's values export. This pins the R8 golden file,
which F5 depends on.

**SPEC edit:** §5.2 R8 — remove the parenthetical open item, state that the
export ends with the date rule. §11 — strike O2.

---

## D3 — §4: pin a card-payload hash alongside the file hash · **Ratified 2026-08-14**

Add to SPEC §4: the fidelity test asserts **two** hashes.

| Hash | Value | Scope |
|---|---|---|
| File SHA-256 | `13a3db92…6847ad8d` | the whole `deck.v1.json`, as §4 already says |
| Card-payload SHA-256 | `10a4c393…775c25d4` | the 83 cards only, canonically serialized |

**Why.** The file hash is self-invalidating by design. Chore C1's sign-off edits
`instrument.verification` *inside* the deck file, so the sanctioned edit breaks
the fidelity test, and `fixtures/README.md` already anticipates re-pinning.
That is fine once, but it means the strongest guarantee in the repo goes soft
at exactly the moment the deck is declared verified. A payload hash survives
metadata edits and keeps *card* drift failing forever.

Verified empirically rather than argued: simulating the C1 edit trips only the
file hash and leaves the payload hash green; tampering with one descriptor
trips both.

**Canonical form.** Separator-delimited, not JSON, so `scripts/check_deck.py`
and `DeckLoader.canonicalPayload(of:)` cannot disagree about key ordering or
string escaping:

```
id U+001F name U+001F descriptor        (per card, in file order)
joined by U+001E
```

Deck v1 is pure ASCII (asserted by a test), so the separators cannot collide
with card data.

> Note: an earlier draft of the plan quoted `86ae6d89…c751037`, a hash of the
> cards as compact sorted-key JSON. Replaced — it depended on two languages'
> JSON encoders agreeing, which is a needless thing to bet a contract on.

**SPEC edit:** §4 — add the payload hash row and the canonical-form definition.

---

## D4 — R8: the export date and locale · **Ratified 2026-08-14**

**Reference/native conflict, resolved in favour of native.**

`reference/valuescardsort.jsx:238` computes the export date as
`new Date().toLocaleDateString("en-US", …)` at render time, so re-exporting a
session completed last March stamps it with **today's** date, and the output
varies by machine region.

**Ratified:** the export renders `session.completedAt`.

**Ratified (the F5 sub-question, answered now):** the body is **locale
formatted as well**. Dates and numbers in the export follow the reader's
locale, not a fixed `en_US_POSIX`. The document belongs to the person who made
it and should read naturally to them, even while the pile labels and the
attribution line remain fixed English strings in 1.0 (localization is roadmap
"Later", SPEC §9).

**Consequence for the harness:** R8's golden-file test must therefore pin both
a fixed date *and* a fixed locale, or it will pass or fail depending on the
machine's region. F5 builds it that way — the test fixes the locale, the app
does not.

**SPEC edit:** §5.2 R8 — name `completedAt` explicitly; add that export
formatting is locale-aware and the golden test pins a locale.

---

## D5 — TESTING.md layer 4: make the accessibility gate a check · **Proposed**

Layer 4 currently reads: *"Accessibility gate evidence (per feature, before
'done') — largest-Dynamic-Type screenshots both appearances; VoiceOver label
audit of the screen's controls; documented in the PR."*

Every other layer is executable. This one is a promise, and it is the layer
covering the requirement SPEC §6 calls a **gate**.

**Proposal.** Layer 4 becomes XCUITest `performAccessibilityAudit()` on every
screen, at default *and* `AccessibilityXXXL` content sizes, plus the existing
screenshots as evidence rather than as the check.

This already earned its place in F1: the audit caught a real clipping bug — the
start button's icon left too little room for its label at accessibility sizes —
that no one would have noticed reading the code.

**Two documented exemptions, both narrow, both on stock chrome:**

- **`.contrast`** — the audit reports "nearly passed" for every text element on
  the root screen, including a semibold primary label on the system grouped
  background at roughly 15:1. It is reporting low confidence behind translucent
  system materials, not a real failure. All flagged elements are stock SwiftUI,
  which SPEC §3.1 deliberately makes Apple's ("the chrome is Apple's; we write
  none of it").
- **`.dynamicType`** — "partially unsupported" on four plain `Text` views using
  stock text styles, at the *default* size. Checked rather than assumed:
  re-running the audit at `AccessibilityXXXL` with those views scrolled into
  view leaves all four unflagged, and exactly one issue survives, on an element
  with no label and no identifier that the app did not author.

  Adversarial review then caught that the blanket exemption was being carried
  into the largest-size tests too, where by that very argument it was not
  needed — which would have switched the check off at exactly the size SPEC §6
  names. Those runs are now scoped by **element ownership** instead: at
  `AccessibilityXXXL`, `.dynamicType` is waived only for elements with no
  identifier and no label, so it still fails on any view the app actually
  wrote. Waived issues are printed on every run rather than silently dropped.

**`.textClipped` is never exempted** — it is the check that found the real bug.

**The exemptions must not spread.** SPEC §6's contrast requirement bites hardest
on the themed card face, where the colours are ours. F8 runs the contrast audit
on themed surfaces with **no** exemption, plus the computed contrast table §6
already demands from the design session.

**Needs a decision from Marty:** the exemptions are a judgment call on a gate,
which is exactly the kind of thing that should not be made silently. If you'd
rather the audit run fully strict and simply fail on stock chrome, say so and
the tests flip.

**TESTING.md edit:** rewrite layer 4; note the exemptions and their scope.

---

## D6 — the deck is compiled in, not bundled as JSON · **Ratified 2026-08-14**

**Directed by the maintainer**, on the grounds that an editable JSON deck is a
vector for harm: this app puts text in front of people at hard moments, and a
card's descriptor altered to something cruel would be easy to miss in a large
JSON diff. Reading the instrument on GitHub is fine and desirable; *editing* it
is what had to be closed off.

**What changed.** `data/deck.v1.json` is a real file again at SPEC §4's path,
and it is now a **build input, not a shipped artifact**.
`scripts/generate_deck.py` compiles it into
`Sources/ValuesCardSortKit/Deck/Deck.v1.generated.swift`. The app links Swift
constants; the bundle contains no `.json` and no resource bundle at all
(verified against a built `.app`). The symlink is gone.

**Four independent locks, each verified by executing the attack:**

| Attack | Caught by |
|---|---|
| Edit a card in `data/deck.v1.json` | both pinned hashes, **and** the regeneration check |
| Edit a card in the generated Swift | the regeneration check, **and** the runtime payload hash |
| Edit both consistently | both pinned hashes (file + card payload) |
| Patch the shipped binary | `DeckLoader.validate` at launch — the app refuses to run a sort |

The pinned payload hash is **hand-maintained in `DeckLoader.swift`, not emitted
by the generator**, so altering a card and the constant guarding it cannot be
one edit to one file. The same constant is pinned in four places: that file,
`scripts/check_deck.py`, this document, and SPEC §4.

The gate also asserts there is no `deck.v*.json` anywhere outside `data/` — no
stray copy that could become shippable.

**The only way a value enters someone's deck at runtime is R4:** a card they
write themselves, in the app.

**Consequence for C1** (now in `fixtures/README.md`): after editing
`instrument.verification`, run `./scripts/generate-deck.sh`, re-pin the new
*file* hash, and confirm the *payload* hash is unchanged. Do it in a local
checkout — the deck is no longer a symlink, but the regeneration step cannot be
performed in GitHub's web editor.

**SPEC edit:** §4 — "The app bundles and loads this exact JSON" becomes: the
app compiles this JSON into its binary; the bundle ships no deck resource. Add
the payload hash and the four-lock description.

-----
August 14, 2026

#AI/Claude
