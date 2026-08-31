# Mutations — web port (`Web/F1`)

**GENERATED** by `scripts/check_web_mutations.py`. Regenerate with:

    python3 scripts/check_web_mutations.py --doc > web/tests/mutations.md

`docs/conventions.md`: *a test that has never been shown to fail is not
evidence.* Each row is a named way to break one rule of the instrument, paired
with the test that must catch it. The runner applies each one to a scratch copy
of the tree and requires the suite to **fail**; a mutation the suite survives is
reported as a hole, which is the point of running it.

`web/tests/rules.test.js` cited this file before it existed — a broken citation
in the document arguing for verification, which is why it is now generated from
the runner rather than maintained by hand.

| ID | Rule | File | Mutation | Caught by |
|---|---|---|---|---|
| `M1` | R2 | `web/index.html` | S.piles[p].push(id);… | R2 a pile keeps assignment order |
| `M2` | R3 | `web/index.html` | S.queue.unshift(last.card);… | R3 undo returns the card to the FRONT |
| `M3` | R4 | `web/index.html` | S.queue.unshift(cid);… | R4 a written card is uppercased and goes to the front |
| `M4` | R4 | `web/index.html` | if (!n) return null;… | R4 a blank name is refused |
| `M5` | R5 | `web/index.html` | if (kept.length < 5 || kept.length > 10) return;… | R5 cull refuses to finish outside the 5-10 band |
| `M6` | R6 | `web/index.html` | return out.concat(draft.promotions);… | R6 promotion order is preserved into the kept set |
| `M7` | R7 | `web/index.html` | if (j < 0 || j >= S.ranking.length) return;… | R7 moving past either end is a no-op |
| `M8` | D4 | `web/index.html` | if (phase === "export" && S.completedAt === null) {… | R8 the export date is completion time |
| `M9` | O2 | `web/index.html` | s += "\n-----\n" + date + "\n";… | R8 the export drops the #AI/Claude tag |
| `M10` | R1 | `web/index.html` | var x = a.slice();… | R1 two sessions do not produce the same order |
| `M11` | SPEC §7 | `web/index.html` | S.history.push({ card: id, pile: p });… | the page touches no storage or network API |
| `M12` | SPEC §4 | `web/deck.js` | "to be accepted as I am"… | the page's deck is the generated one |
| `M14` | SPEC §7 | `web/index.html` | S.history.push({ card: id, pile: p });… | the page touches no storage or network API |
| `M15` | R8 | `web/index.html` | s += "\n## Full sort\n";
  for (var p = 4; p >= 0; p--) {… | R8 the markdown export matches the golden file |
| `M16` | R8 | `web/index.html` | var ids = (p === 4) ? S.ranking : S.piles[p];
    if (!ids.lengt… | R8 the markdown export matches the golden file |
| `M17` | R8 | `web/index.html` | s += "Completed: " + date + "\n\n## Top values (ranked)\n\n";… | R8 the markdown export matches the golden file |
| `M18` | R8 | `web/index.html` | s += "- " + c.name + " - " + c.descriptor + "\n";… | R8 the markdown export matches the golden file |
| `M19` | R3 | `web/index.html` | if (i === -1) return;            // state already malformed; do … | R3 undo refuses to act on a malformed state |
| `M13` | R2 | `web/index.html` | "Most important to me"… | R8 markdown carries every pile |

**19 mutations, all caught.** `M8` and `M13` were added after
mutation testing found the tests for them tautological; `M14` is the attack that
defeated the first privacy gate; `M15`–`M18` are the export mutations that
survived until R8 had a golden file.
