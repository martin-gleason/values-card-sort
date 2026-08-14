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

## D5 — the accessibility gate has no exemptions · **Ratified 2026-08-14**

TESTING.md layer 4 read: *"Accessibility gate evidence (per feature, before
'done') — largest-Dynamic-Type screenshots both appearances; VoiceOver label
audit of the screen's controls; documented in the PR."* Every other layer is
executable; this one — covering the requirement SPEC §6 calls a **gate** — was
a promise.

**Ratified:** layer 4 becomes XCUITest `performAccessibilityAudit()` on every
screen, at default *and* `AccessibilityXXXL` content sizes, with **no
exemptions of any kind**. Screenshots remain as evidence, not as the check.
Every audit rule runs everywhere; an issue is fixed in the view, never waived
in the test. The waiver machinery an earlier draft proposed has been deleted
rather than narrowed.

**What this cost, and it is not nothing — see D7.**

**What it bought,** all of which are real defects the gate forced out:

1. A clipped button label at accessibility sizes (the icon took width the text
   needed).
2. White-on-accent button text at **4.02:1**, under §6's 4.5:1 floor — the
   system blue does not meet the contrast bar this spec sets. Fixed with an
   `AccentColor` asset: **6.39:1** light, **5.17:1** dark, ratios computed
   rather than eyeballed.
3. Contrast flags that were genuinely unanswerable rather than wrong: the audit
   cannot resolve a ratio behind translucent material, and opaque row
   backgrounds made the real ratio computable.

**TESTING.md edit:** rewrite layer 4 as above; state that there are no
exemptions.

---

## D7 — SwiftUI `List` cannot pass a strict accessibility audit · **Needs a decision**

**This is the cost of D5, and it collides with SPEC §3.1.**

§3.1 says "navigation, **lists**, sheets, pickers, share: stock SwiftUI. The
chrome is Apple's; we write none of it." With `List`, the F1 root screen
produced **six** audit issues under D5's no-exemption rule:

- `Dynamic Type: partially unsupported` on four plain `Text` rows that use
  stock text styles and demonstrably do scale correctly (the largest-size
  screenshots show them wrapping perfectly).
- `Contrast nearly passed` on the two `Section` headers, which are the
  system's own grey.

Every remedy was tried and measured, not assumed: explicit `.font` text styles,
explicit `.foregroundStyle(.primary)`, `.fixedSize(horizontal:vertical:)`,
`.listStyle(.plain)` and inset-grouped, `.listRowBackground` with opaque
colours, wrapping row content in a `VStack`, collapsing rows into single
explicit accessibility elements, and scrolling every row fully into view. **The
count never went below six.** The identical content in a `ScrollView` audits
clean. The flags live in `List`'s backing store, not in the content.

**What shipped for F1:** `App/Views/GroupedSurface.swift`, a hand-built
inset-grouped surface using the system's own grouped-background colours, the
system corner radius, and Dynamic Type styles throughout. It is visually the
platform's grouped list — nothing themed, nothing invented, no design boldness,
so §3.1's *intent* holds even though its letter does not. Screenshots in
`docs/evidence/f1/`.

**Why this needs your decision anyway:**

- It is a literal departure from a ratified spec sentence, made to satisfy a
  ratified gate. One of the two has to give, and that is your call, not mine.
- **F6 is where it really bites.** The session history is genuinely a list and
  wants swipe-to-delete, which `List` provides and a `ScrollView` does not. At
  F6 the choice is: stock `List` with a failing audit, `List` with the first
  exemption, or hand-built rows plus hand-built delete affordances.

**Options:**

1. **Amend §3.1** to say stock components *except where they fail the §6 gate*,
   and keep building on `GroupedSection`. Consistent with D5 as ratified.
2. **Keep §3.1 literal** and reinstate a documented `List`-only exemption,
   which reopens D5.
3. **Split the difference:** stock `List` wherever it audits clean, hand-built
   only where it does not, deciding case by case at each gate.

My recommendation is **(1)**: you ratified the accessibility gate as absolute,
and this is what absolute costs. But it should be ratified explicitly rather
than absorbed silently.

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
