# Fixtures — instrument source documents (chore C1)

The card-by-card fidelity claim in SPEC §2 is **pending** until the source PDFs live here and the verification runs.

## C1 procedure

1. **Marty** downloads both PDFs into this folder (keep these names):
   - `valuescardsort-mint-2001.pdf` ← https://motivationalinterviewing.org/sites/default/files/valuescardsort_0.pdf
   - `valuescardsort-casaa-2001.pdf` ← https://casaa.unm.edu/assets/inst/personal-values-card-sort.pdf
2. **Claude** extracts every card (number, NAME, descriptor) from the PDFs and diffs all 83 against `data/deck.v1.json` — names *and* descriptors, character-for-character — and reports the diff (expected: empty; any mismatch is a finding, and the deck file wins only after ratification).
3. **Marty** reviews the diff report and signs off by changing `instrument.verification` in `data/deck.v1.json` — the one sanctioned edit. Then:
   1. `./scripts/generate-deck.sh` — the deck is compiled into Swift, so the edit has to be regenerated or CI's regeneration check fails.
   2. Re-pin the new **file** hash in `scripts/check_deck.py` (`FILE_SHA256`) and SPEC §4.
   3. The **card-payload** hash must NOT change. If it does, something touched a card, and that is not a sign-off — it is drift.
   4. `./scripts/check-deck.sh` to confirm all ten checks pass.

   **Do this in a local checkout, not GitHub's web editor.**

Already verified without the fixture (via source fetch, 2026-08-14): 83 numbered cards; category headers IMPORTANT TO ME / VERY IMPORTANT TO ME / NOT IMPORTANT TO ME; three blank "Other Value:" cards; first 10 and last 10 card names match the deck exactly.

-----
August 14, 2026

#AI/Claude
