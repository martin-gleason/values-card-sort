# Design Handoff — Card Themes for Values Card Sort: Digital Tool

**For:** a Claude design session (load this document; skills to lean on: canvas-design, mobile-design, frontend-design)
**From:** the spec/harness session, August 14, 2026
**Feeds:** feature **F8** (theme engine + three themes) — this handoff is chore **C5** on the project plan
**Maintainer:** Marty Gleason. He ratifies; you propose.

---

## Context in one paragraph

We are building a free, copyleft (GPL-3.0-or-later), native SwiftUI app of the public-domain **Personal Values Card Sort** (Miller, C'de Baca, Matthews & Wilbourne, University of New Mexico, 2001) for iPhone, iPad, and Mac. The person sorts 83 value cards into five piles, keeps 5–10, ranks them, exports. The app's chrome is entirely stock Apple components — **all design boldness lives in exactly one place: the card face and the desk surface it sits on.** A "theme" skins those two things and nothing else. v1.0 ships three themes: **Note Card**, **Civic**, and **Mucha**. In v1.5 users will design their own cards, so themes must come back as *data* (tokens + vector assets), not as bespoke code.

## What this session must produce (the deliverable back to the build)

For **each** of the three themes:

1. **A theme definition** filled into the schema below — palette (light *and* dark), typography intent, card-face treatment, desk-surface treatment.
2. **Vector assets** (SVG, no embedded raster) for any ornament: border/frame elements, rules, corner devices, background motifs. Ornament must be separable from text — text is always live type rendered by the app, never part of the artwork.
3. **A contrast table**: card-name and descriptor text over their actual backgrounds, light and dark, with computed ratios. Body ≥ 4.5:1, large text ≥ 3:1. A theme that fails contrast gets revised here, not in the build.
4. **Two mock renderings** per theme: the full card (sort screen) and a small thumbnail (history list) so we know the theme survives both sizes.

Plus one shared item: 5. **A ratified answer to the Civic question** (below) from Marty, recorded in the output.

## Fixed card anatomy (themes may not change this)

- The card face displays: **value NAME** (dominant) and **descriptor** (subordinate, e.g. *"to be accepted as I am"*). Nothing else is guaranteed present.
- Text is set by the app in **Dynamic Type** styles — the card grows vertically at large accessibility sizes. Ornament must anchor to edges/corners and tolerate any card height; nothing critical may sit behind text.
- Touch/click targets and all chrome (pile buttons, nav, toolbars) are native and unthemed.
- Every theme must work in **light and dark** appearance, and degrade gracefully with Reduce Motion (no motion is required at all — rotation/settle effects are optional decoration) and Increase Contrast.

## Theme 1 — Note Card (the default; port, don't reinvent)

The reference implementation's index-card vernacular, already loved. Tokens extracted from `reference/valuescardsort.jsx`:

| Token | Value | Role |
|---|---|---|
| FELT | `#20392F` | desk surface (deep felt green) |
| PAPER | `#FDFCF6` | card stock |
| INK | `#25322C` | card text |
| RULE | `#C9DEE9` | ruled lines, repeating every 32px |
| REDRULE | `#DB9A93` | single red top rule (at ~44px from top) |
| ACCENT | `#C75146` | primary actions, rank numerals |
| CREAM | `#F3EFE4` | light text on felt |
| MUTED | `#9BB4A9` | secondary text on felt |

Type intent: NAME in heavy tracking-wide sans (was 800 weight, 0.08em letterspacing); descriptor in *italic serif* (was Georgia). Card sits at a −0.4° rotation on the felt (decorative; must respect Reduce Motion if animated, and can be dropped at small sizes). **Design task:** translate this faithfully into the schema + dark-mode variant (proposal: felt darkens, paper warms down, ink lightens — keep the ruled-paper metaphor legible), don't redesign it.

## Theme 2 — Civic ⚠️ open question first

**O4 (ratify with Marty before designing):** which "civic"?

- **(a) WPA-era public works poster** — flat ink, cream stock, engraved municipal seals/eagles vibe, big grotesque caps, the aesthetics of a 1938 parks department broadside.
- **(b) Modern civic-tech / government-forms** — USWDS-adjacent cleanliness, form rules, stamp and perforation devices, official-document calm.

Design the one he picks (or his third meaning). Either way: the theme should feel like *public service made beautiful* — sturdy, institutional-warm, zero corporate gloss. Marty's world is courts, probation, civic duty; this theme is his home turf. Keep ornament flat and printable — it must survive as a small thumbnail.

## Theme 3 — Mucha (Art Nouveau)

Alphonse Mucha's visual language: ornamental frames, halo arcs, botanical whiplash curves, muted golds/olives/dusty roses. Reference for *looking*: https://www.muchafoundation.org/en (link supplied by Marty).

**IP guardrails (hard):**

- **Original, Mucha-inspired ornament only.** Mucha's own works are public domain (d. 1939), but do **not** reproduce or trace specific artworks, and do **not** use the Mucha Foundation's photography, scans, or marks. Style is not copyrightable; reproductions and their curated scans are murkier — we stay clean by drawing our own.
- No figures/faces (his women are his signature — an app card with a traced Mucha figure reads as reproduction). Frames, borders, halos, botanicals: yes.
- Assets ship under the repo's GPL-3.0-or-later, so everything must be ours.

Design challenge: Art Nouveau ornament is dense; the card must stay a *reading surface*. Frame the text, never compete with it. Prove it in the contrast table and the thumbnail mock.

## Theme schema (draft v0 — refine it, then it becomes the F8 contract)

```json
{
  "schemaVersion": "0.1",
  "id": "note-card",
  "displayName": "Note Card",
  "appearance": {
    "light": {
      "desk": { "fill": "#20392F", "texture": null },
      "card": {
        "stock": "#FDFCF6",
        "cornerRadius": 2,
        "rotationDegrees": -0.4,
        "shadow": "systemDefault",
        "ornament": { "asset": null, "placement": "none" },
        "rules": { "pattern": "horizontal", "color": "#C9DEE9", "spacing": 32,
                   "topRule": { "color": "#DB9A93", "offset": 44, "weight": 2 } },
        "name": { "textStyle": "title2", "weight": "heavy", "tracking": 0.08, "color": "#25322C", "case": "upper" },
        "descriptor": { "textStyle": "body", "design": "serif", "italic": true, "color": "#25322C" }
      },
      "accent": "#C75146"
    },
    "dark": { "…": "same shape, dark values" }
  }
}
```

Notes for the schema work: `textStyle` values are Apple Dynamic Type styles (never point sizes); `asset` references an SVG in the theme bundle; add fields as the designs demand, but keep everything declarative — v1.5's "design your own card" is this schema with a UI on top.

## Constraints checklist (every theme, before handing back)

- [ ] Light + dark variants defined
- [ ] Contrast table passes (4.5:1 body / 3:1 large)
- [ ] Full-size and thumbnail mocks both legible
- [ ] Ornament is edge/corner-anchored; card height is variable; nothing behind text
- [ ] All assets original vector work, GPL-compatible, no raster
- [ ] Typography expressed as Dynamic Type styles + weight/design modifiers only
- [ ] Theme definition validates against the (refined) schema

-----
August 14, 2026

#AI/Claude
