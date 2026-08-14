# Values Card Sort: Digital Tool — Specification

**Version:** 1.0-draft (awaiting maintainer ratification)
**Maintainer:** Martin "Marty" Gleason
**Status:** Contract. The agent may propose deltas; the maintainer ratifies them. The agent never edits this file on its own authority.

---

## 1. Purpose

A free, open-source, native Apple app (iOS, iPadOS, macOS — one SwiftUI codebase) of the **Personal Values Card Sort**, so that people who are struggling can find and rank their personal values on the device they already own, privately, at no cost. It is a **tool, not a project**: small, finished, and faithful.

The app is the native successor to the single-file React reference implementation (`reference/valuescardsort.jsx`), which remains the behavioral reference for phase rules.

## 2. Instrument provenance and fidelity

| Fact | Status |
|---|---|
| Instrument: *Personal Values Card Sort*, W. R. Miller, J. C'de Baca, D. B. Matthews, P. L. Wilbourne, University of New Mexico, 2001 | Verified against the MINT resource page |
| Public domain | Verified (stated on MINT resource page) |
| 83 numbered value cards | Verified against source PDF (first 10 and last 10 match `data/deck.v1.json` exactly) |
| Original category header cards: **IMPORTANT TO ME / VERY IMPORTANT TO ME / NOT IMPORTANT TO ME** (3 categories) | Verified against source PDF |
| Three blank "Other Value:" cards included in the original deck | Verified against source PDF |
| Card-by-card verification of all 83 names + descriptors against the source PDF | **PENDING — chore C1** (PDFs land in `fixtures/`, agent verifies, maintainer signs off) |

Source URLs (pinned):

- Resource page: https://motivationalinterviewing.org/personal-values-card-sort
- PDF (MINT): https://motivationalinterviewing.org/sites/default/files/valuescardsort_0.pdf
- PDF (CASAA/UNM): https://casaa.unm.edu/assets/inst/personal-values-card-sort.pdf

### 2.1 Deviations from the paper instrument (documented, deliberate)

| # | App behavior | Paper instrument | Classification |
|---|---|---|---|
| D1 | **Five** piles (Not / Somewhat / Important / Very / Most important to me) | Three categories | Deliberate refinement — finer first-pass triage; the top pile ("Most important") plays the role the paper's "Very important" pile plays in administration |
| D2 | Cull to **5–10** values | Not printed on the instrument; common MI administration guidance | Adopted administration convention |
| D3 | **Promotion** from "Very important" when the top pile holds fewer than 5 | Not in the instrument | App invention (marked as such in-app copy is not required, but this table is the record) |
| D4 | Forced **ranking** of the kept values | Common administration step, not printed | Adopted administration convention |
| D5 | Unlimited user-written cards | Three blank "Other Value:" cards | Faithful in kind, unbounded in count |
| D6 | One card presented at a time from a shuffled deck | Physical deck, sorter's own pace/order | Digital adaptation |

The About screen links to the source PDF and states that this is an adaptation with the deviations above summarized in one sentence.

## 3. Platforms and technology

- **SwiftUI multiplatform, one codebase**, native targets: iOS, iPadOS, macOS. No Catalyst, no web view.
- **Proposed minimums (ratify):** iOS/iPadOS 18, macOS 15. Built against the current SDK (Xcode 26 / iOS 26 family) so system chrome inherits the current design language on recompile.
- **Persistence:** SwiftData, local store only. No CloudKit in 1.0 (door left open — no design decision may preclude adding CloudKit later without a rewrite).
- **Tests:** Swift Testing for unit/rule tests; XCUITest reserved for the accessibility gate where needed.
- **No third-party dependencies** in the app target unless ratified. (Snapshot-testing package permitted in the test target if F8 needs it.)

### 3.1 Design stance (binding, from the mobile-design skill)

- **System-components-first, content-flat.** Navigation, lists, sheets, pickers, share: stock SwiftUI. The chrome is Apple's; we write none of it.
- **The card face is the single signature element.** All design boldness — and all theming — lives on the card face and its desk surface. Themes never touch chrome, navigation, or system controls.
- Semantic colors and Dynamic Type text styles everywhere outside the themed card face; even the card face must honor Dynamic Type scaling.

## 4. Data contract

- `data/deck.v1.json` — the 83-card deck, extracted programmatically from the reference implementation (no hand transcription). SHA-256 of the file at extraction: `13a3db92c997eb98679237fe3ddf22b40d4379528a9f991bbf1894ef6847ad8d`.
- The deck file is **immutable once C1 sign-off lands**. Any change is a new versioned file (`deck.v2.json`) plus a ratified spec delta.
- The app bundles and loads this exact JSON; a **fidelity test** asserts count = 83 and the file hash, so deck drift fails CI.
- Deck data is public domain (the instrument's status); the repo's copyleft license applies to code and original art, not to the instrument data.

## 5. Product specification

### 5.1 Session model

A **session** is one complete run of the instrument.

- Fields: id, startedAt, completedAt (nil while in progress), deckVersion, shuffle order, pile assignments, sort history (for undo), cull state, ranking, custom cards, phase, theme in use.
- **At most one in-progress session** at a time; completed sessions are archived with their date.
- **Re-sort** = start a new session (fresh shuffle). Custom cards from prior sessions are offered for inclusion at session start (they are the user's personal deck extension).
- Sessions can be viewed (read-only results) and deleted. Deleting requires confirmation.

### 5.2 Phase rules (pinned from the reference implementation; each rule gets a named test)

**R1 — Shuffle.** Deck order is a uniform random shuffle (Fisher–Yates) fixed at session start and persisted.
**R2 — Sort.** One card at a time from the front of the queue; the sorter assigns it to exactly one of five piles: *Not important to me · Somewhat important to me · Important to me · Very important to me · Most important to me* (these five labels are contract).
**R3 — Undo.** Undo is LIFO over the sort history; the undone card returns to the **front** of the queue and leaves its pile.
**R4 — Custom card.** A user-written card (name required, uppercased; descriptor optional, default "a value I wrote myself") is inserted at the **front** of the queue. Custom cards are available during Sort, including after the queue empties.
**R5 — Cull.** Cull operates on the *Most important* pile. Cutting a card marks it; cut cards land in *Very important* on completion. If kept < 5 and *Very important* is non-empty, cards may be promoted from *Very important*.
**R6 — Cull gate.** Cull completes only when 5 ≤ kept ≤ 10. Kept order = surviving *Most important* order, then promotions in promotion order.
**R7 — Rank.** The kept list is reordered by the user. Position 1 is the most central value. Native idiom: drag-to-reorder with accessibility reorder actions; up/down controls remain available.
**R8 — Export.** Markdown export with: title; instrument attribution line (authors, institution, year, public domain); completion date; ranked top values (numbered, name + descriptor); full sort by pile, top pile first, using the ranked order for the top pile; empty piles marked *(empty)*; footer rule + date. *(Open item O2: the reference implementation ends with a `#AI/Claude` tag — personal convention; proposed **dropped** from the public build.)* Delivery: system share sheet (`ShareLink`) + copy. A shareable summary-card **image** export is F5-scoped if cheap, else moves to 1.1.
**R9 — Reset / abandon.** Destroying an in-progress session requires explicit confirmation.
**R10 — Resume.** The app resumes an in-progress session exactly where it left off, mid-phase, across launches.
**R11 — Keyboard.** With a hardware keyboard (macOS, iPadOS): keys 1–5 assign to piles, U undoes. Full Keyboard Access must work on every screen.

### 5.3 Themes (v1.0 ships three)

- A **theme** skins the card face and desk surface only, defined by a machine-readable theme definition (schema owned by F8; the design handoff `docs/design/design-handoff-card-themes.md` is the contract with the design session).
- v1.0 themes: **Note Card** (port of the reference implementation's ruled-index-card design — the default), **Civic**, **Mucha** (Art Nouveau, original Mucha-*inspired* art only).
- Theme choice is global (Settings), applies immediately, and is recorded on completed sessions.
- v1.5 ("design your own card") depends on themes being data, not code — F8 must keep theme definitions declarative.

### 5.4 History and export surfaces

- Session list (dated, newest first) → session detail (ranked values, full piles, re-export).
- Compare view between two sessions is **out of scope for 1.0** (roadmap 1.1).

### 5.5 About / Settings

- Attribution: instrument authors, UNM, 2001, public domain, links to the source PDF and resource page.
- License notice (GPL-3.0-or-later), link to the repository.
- Theme picker. Nothing else in 1.0 — no accounts, no toggles that imply data leaves the device.

## 6. Accessibility (a gate, not a feature)

Every screen passes before its feature is done:

- Dynamic Type on every text element **including the themed card face**, verified at the largest accessibility size, light and dark.
- Contrast ≥ 4.5:1 body / ≥ 3:1 large text — themes are rejected at review if ornament sinks text below this.
- Descriptive VoiceOver labels on every control; the sort screen is fully operable with VoiceOver (pile buttons announce label + count; card announces name + descriptor).
- Touch targets ≥ 44 pt. Reduce Motion honored (card rotation/transition effects are decorative and must degrade). No color-only meaning.

## 7. Privacy (binding)

- **Local-only. No network code, no analytics, no accounts, no third-party SDKs.** The binary makes zero network connections; nothing in the codebase may import a networking API for app functionality.
- Privacy policy (needed for TestFlight/App Store): "Everything you enter stays on your device. This app makes no network connections and collects nothing."

## 8. Licensing and distribution

- **Code and original art: GPL-3.0-or-later** (copyleft, per maintainer decision). SPDX headers on source files.
- Instrument data (`data/deck.v*.json` content): public domain, attributed.
- Attributions in-app and in README: Miller, C'de Baca, Matthews & Wilbourne (2001), University of New Mexico, with the pinned source links.
- Distribution: **public GitHub repository + TestFlight** first; App Store later (roadmap). Note for contributors (CONTRIBUTING): the maintainer distributes via TestFlight/App Store; contributions are accepted under GPL-3.0-or-later with that distribution understood. (Sole-author distribution poses no GPL/App Store conflict; this note is what keeps it true once there are outside contributors.)

## 9. Roadmap

| Version | Contents |
|---|---|
| **1.0** | Everything in §5–§8: sort/cull/rank/export, sessions + re-sort, custom cards, three themes, About, TestFlight |
| 1.1 | Session compare view (what rose, fell, left the top 10); summary-card image export if it slipped from 1.0 |
| 1.5 | **Design your own card** — user-facing theme designer built on the F8 declarative theme schema |
| Later | App Store release; localization; Schwartz PVQ-RR remains out of scope entirely |

## 10. Feature list (structural IDs per conventions)

| ID | Feature | Notes |
|---|---|---|
| F1 | Foundation: project scaffold, deck contract loader, SwiftData session model, fidelity tests (R1 partial) | First gate after harness ratification |
| F2 | Sort phase (R1–R4, R9–R11) | |
| F3 | Cull phase (R5, R6) | |
| F4 | Rank phase (R7) | |
| F5 | Export (R8) | |
| F6 | Sessions & history (§5.1, §5.4) | |
| F7 | Custom cards across sessions | |
| F8 | Theme engine + Note Card, Civic, Mucha | **Blocked by C5** (design session returns theme specs) |
| F9 | About / Settings / attribution | |
| F10 | Accessibility audit + polish | Final gate before TestFlight |

**Chores (human track):**

| ID | Chore | Owner |
|---|---|---|
| C1 | Download both source PDFs into `fixtures/`, then review the agent's card-by-card verification and sign off | Marty |
| C2 | Apple Developer Program enrollment ($99/yr) | Marty |
| C3 | Create the GitHub repository; enable branch protection on `main` | Marty |
| C4 | App Store Connect + TestFlight setup, beta review submission | Marty |
| C5 | Run the design session with `docs/design/design-handoff-card-themes.md`; bring back theme specs | Marty |

## 11. Open items for ratification

- **O1** — Minimum OS versions (proposed iOS/iPadOS 18, macOS 15).
- **O2** — Export footer: drop the `#AI/Claude` tag in the public build (proposed: drop).
- **O3** — Summary-card image export in 1.0 or 1.1.
- **O4** — "Civic" theme interpretation (see design handoff — answer it in the design session).
- **O5** — App icon: separate logo-rules session, timing.

-----
August 14, 2026

#AI/Claude
