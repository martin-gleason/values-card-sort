# Fixtures — instrument source documents (chore C1)

The card-by-card fidelity claim in SPEC §2 is **pending** until the source PDFs live here and the verification runs.

## C1 procedure

1. **Marty** downloads both PDFs into this folder (keep these names):
   - `valuescardsort-mint-2001.pdf` ← https://motivationalinterviewing.org/sites/default/files/valuescardsort_0.pdf
   - `valuescardsort-casaa-2001.pdf` ← https://casaa.unm.edu/assets/inst/personal-values-card-sort.pdf
2. **Claude** extracts every card (number, NAME, descriptor) from the PDFs and diffs all 83 against `data/deck.v1.json` — names *and* descriptors, character-for-character — and reports the diff (expected: empty; any mismatch is a finding, and the deck file wins only after ratification).
3. **Marty** reviews the diff report and signs off by changing `instrument.verification` in `data/deck.v1.json` — this is the one sanctioned edit, after which the file's new hash is recorded in SPEC §4 and CI, and the deck is frozen.

Already verified without the fixture (via source fetch, 2026-08-14): 83 numbered cards; category headers IMPORTANT TO ME / VERY IMPORTANT TO ME / NOT IMPORTANT TO ME; three blank "Other Value:" cards; first 10 and last 10 card names match the deck exactly.

-----
August 14, 2026

#AI/Claude
