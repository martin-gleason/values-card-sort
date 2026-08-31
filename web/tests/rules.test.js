// SPDX-License-Identifier: GPL-3.0-or-later
//
// Rule fidelity for the web port — R1–R11, run headlessly under `node --test`.
//
// **Why this exists.** The plan names one risk above all others: the state
// machine is the whole product, and a port that is 95% faithful is a different
// instrument. The native side proves R1–R11 with Swift Testing; this surface
// had no harness at all, so one had to be built.
//
// **Why it has no dependencies.** The page's whole claim is that view-source is
// the entire program — no bundler, no node_modules, no CDN. A test suite that
// dragged in jsdom would be a strange thing to hang off that. The DOM shim
// below is about ninety lines and fakes only the DOM: it never reimplements a
// rule. Every assertion here runs the real functions out of web/index.html.
//
// **What makes it evidence rather than decoration.** The suite is paired with
// mutations in web/tests/mutations.md — each one a named way to break a rule,
// with the test that must catch it. A test never shown to fail is not evidence,
// and this repository has already been bitten by a suite that passed while the
// code under it was wrong.
//
//   node --test web/tests/

const { test } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const WEB = path.join(__dirname, "..");

/* ===========================================================================
   A DOM, in as few lines as will hold the page up.

   Element ids are read out of index.html rather than listed here, so the shim
   cannot silently fall out of step with the markup: rename an id in the page
   and the element simply exists under its new name.
   ======================================================================== */

function makeElement(tag) {
  const el = {
    tagName: String(tag).toUpperCase(),
    children: [],
    attrs: {},
    _text: "",
    className: "",
    style: {},
    hidden: false,
    disabled: false,
    value: "",
    tabIndex: 0,
    offsetParent: {},
    _listeners: {},

    get textContent() {
      return this.children.length
        ? this.children.map((c) => c.textContent).join("")
        : this._text;
    },
    set textContent(v) {
      // Assigning textContent replaces all children — the page relies on
      // `list.textContent = ""` to clear a list before re-rendering it.
      this.children = [];
      this._text = String(v);
    },

    appendChild(c) { this.children.push(c); return c; },
    removeChild(c) { this.children = this.children.filter((x) => x !== c); return c; },
    setAttribute(k, v) { this.attrs[k] = String(v); },
    getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; },
    addEventListener(type, fn) { (this._listeners[type] ||= []).push(fn); },
    removeEventListener() {},
    focus() {},
    select() {},
    showModal() { this.open = true; },
    close() { this.open = false; },
    click() { (this._listeners.click || []).forEach((fn) => fn({ preventDefault() {} })); },

    // Depth-first descendant search over the shim's own tree.
    descendants() {
      return this.children.flatMap((c) => [c, ...c.descendants()]);
    },
    querySelectorAll(sel) { return matchAll(this, sel); },
    querySelector(sel) { return matchAll(this, sel)[0] || null; },
  };
  return el;
}

// Enough selector support for what the page actually asks for: "#id tag",
// "tag", and "[attr=\"value\"][attr2=\"value2\"]".
function matchAll(root, sel) {
  sel = sel.trim();
  const scope = sel.startsWith("#")
    ? (byId[sel.slice(1).split(/\s+/)[0]] || makeElement("div"))
    : root;
  const rest = sel.startsWith("#") ? sel.split(/\s+/).slice(1).join(" ").trim() : sel;
  const pool = scope.descendants();
  if (!rest) return pool;

  if (rest.startsWith("[")) {
    const pairs = [...rest.matchAll(/\[([\w-]+)="([^"]*)"\]/g)].map((m) => [m[1], m[2]]);
    return pool.filter((e) => pairs.every(([k, v]) => e.getAttribute(k) === v));
  }
  return pool.filter((e) => e.tagName === rest.toUpperCase());
}

const byId = Object.create(null);

function buildDOM() {
  const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
  for (const key of Object.keys(byId)) delete byId[key];
  for (const m of html.matchAll(/\bid="([\w-]+)"/g)) {
    byId[m[1]] = makeElement("div");
  }
  const body = makeElement("body");
  return {
    document: {
      getElementById: (id) => byId[id] || null,
      createElement: makeElement,
      createTextNode: (t) => {
        const n = makeElement("#text");
        n._text = String(t);
        return n;
      },
      addEventListener() {},
      querySelector: (s) => matchAll(body, s)[0] || null,
      querySelectorAll: (s) => matchAll(body, s),
      body,
    },
    body,
  };
}

/** Loads web/index.html's script and web/deck.js into a fresh context. */
function load() {
  const { document } = buildDOM();
  const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
  const appSrc = html.match(/<script>\n([\s\S]*?)\n<\/script>/)[1];
  const deckSrc = fs.readFileSync(path.join(WEB, "deck.js"), "utf8");

  const sandbox = {
    document,
    crypto,
    console,
    setTimeout,
    navigator: {},
    window: { addEventListener() {}, scrollTo() {} },
    URL: { createObjectURL: () => "blob:x", revokeObjectURL() {} },
    Blob: function () {},
  };

  /* Every storage and network API the browser would offer, replaced by a trap
     that records the attempt.

     This is the privacy gate that actually holds. The previous one grepped the
     source for banned names after stripping comments with a regex, and two
     string literals containing the comment delimiters were enough to hide a
     `localStorage` write and a network call from it while the suite stayed
     33/33 green. Text can be hidden from a reader; a call cannot be hidden
     from the thing being called. This also catches forms no grep would —
     `window["local" + "Storage"]`, or a reference taken before use.

     Static scanning still happens, but in scripts/check_web_privacy.py, which
     has a string-aware scanner and its own tests. */
  const touched = [];
  for (const name of [
    "localStorage", "sessionStorage", "indexedDB", "openDatabase",
    "fetch", "XMLHttpRequest", "WebSocket", "EventSource", "Image", "Audio",
    "Worker", "SharedWorker", "RTCPeerConnection", "importScripts",
  ]) {
    Object.defineProperty(sandbox, name, {
      configurable: true,
      get() { touched.push(name); throw new Error(`privacy: the page touched ${name}`); },
    });
  }
  sandbox.navigator = {};
  for (const name of ["sendBeacon", "geolocation", "mediaDevices", "serviceWorker"]) {
    Object.defineProperty(sandbox.navigator, name, {
      configurable: true,
      get() { touched.push(`navigator.${name}`); throw new Error(`privacy: navigator.${name}`); },
    });
  }
  Object.defineProperty(document, "cookie", {
    configurable: true,
    get() { touched.push("document.cookie"); throw new Error("privacy: document.cookie"); },
    set() { touched.push("document.cookie="); throw new Error("privacy: document.cookie="); },
  });

  sandbox.globalThis = sandbox;
  sandbox.window.addEventListener = () => {};
  vm.createContext(sandbox);
  vm.runInContext(deckSrc, sandbox);
  vm.runInContext(appSrc, sandbox);
  return { T: sandbox.VCS_TEST, deck: sandbox.VCS_DECK_V1, byId, touched };
}

/** Sorts the whole deck, sending `topN` cards to Most important. */
function sortAll(T, topN) {
  let i = 0;
  while (T.state().queue.length) { T.assign(i < topN ? 4 : i % 4); i++; }
}

/* ===========================================================================
   R1 — Shuffle
   ======================================================================== */

test("R1 the shuffle is a complete permutation of the deck", () => {
  const { T, deck } = load();
  const s = T.state();
  assert.equal(s.shuffleOrder.length, deck.cardCount);
  assert.equal(new Set(s.shuffleOrder).size, deck.cardCount);
  const expected = new Set(deck.cards.map((c) => "deck:" + c.id));
  assert.deepEqual(new Set(s.shuffleOrder), expected);
});

test("R1 the shuffle order is fixed at start and never mutated by sorting", () => {
  const { T } = load();
  const order = T.state().shuffleOrder.slice();
  sortAll(T, 6);
  assert.deepEqual(T.state().shuffleOrder, order);
  assert.equal(T.state().queue.length, 0);
});

test("R1 two sessions do not produce the same order", () => {
  const a = load().T.state().shuffleOrder.join();
  const b = load().T.state().shuffleOrder.join();
  assert.notEqual(a, b);
});

/* ===========================================================================
   R2 — Sort
   ======================================================================== */

test("R2 a card goes to exactly one pile and leaves the queue", () => {
  const { T } = load();
  const first = T.state().queue[0];
  const n = T.state().queue.length;
  T.assign(2);
  const s = T.state();
  assert.equal(s.queue.length, n - 1);
  assert.deepEqual(s.piles[2], [first]);
  assert.equal(s.piles.flat().filter((x) => x === first).length, 1);
  assert.deepEqual(s.history[0], { card: first, pile: 2 });
});

test("R2 a pile keeps assignment order, because the export depends on it", () => {
  const { T } = load();
  const first3 = T.state().queue.slice(0, 3);
  T.assign(4); T.assign(4); T.assign(4);
  assert.deepEqual(T.state().piles[4], first3);
});

test("R2 assigning with an empty queue is a no-op, not a trap", () => {
  const { T } = load();
  sortAll(T, 5);
  const snapshot = JSON.stringify(T.state());
  T.assign(0);
  assert.equal(JSON.stringify(T.state()), snapshot);
});

test("R2 every card is conserved across a full sort", () => {
  const { T, deck } = load();
  sortAll(T, 7);
  const s = T.state();
  assert.equal(s.piles.flat().length, deck.cardCount);
  assert.equal(new Set(s.piles.flat()).size, deck.cardCount);
});

/* ===========================================================================
   R3 — Undo
   ======================================================================== */

test("R3 undo returns the card to the FRONT of the queue", () => {
  const { T } = load();
  const first = T.state().queue[0];
  T.assign(1);
  const second = T.state().queue[0];
  T.undo();
  assert.equal(T.state().queue[0], first);
  assert.equal(T.state().queue[1], second);
  assert.deepEqual(T.state().piles[1], []);
  assert.equal(T.state().history.length, 0);
});

test("R3 undo on empty history is a no-op", () => {
  const { T } = load();
  const snapshot = JSON.stringify(T.state());
  T.undo();
  assert.equal(JSON.stringify(T.state()), snapshot);
});

test("R3 undo is LIFO and a full unwind restores the original order", () => {
  const { T } = load();
  const order = T.state().shuffleOrder.slice();
  sortAll(T, 9);
  while (T.state().history.length) T.undo();
  assert.deepEqual(T.state().queue, order);
  assert.deepEqual(T.state().piles, [[], [], [], [], []]);
});

test("R3 undo refuses to act on a malformed state rather than duplicating a card", () => {
  const { T } = load();
  T.assign(2);
  const s = T.state();
  // Corrupt the state the way a future bug would: history says the card is in
  // the pile, and it is not. The reference's filter() is idempotent here; this
  // port uses indexOf/splice, which is not, so it carries an explicit guard.
  // Without the guard the card is prepended to the queue while still counted
  // as placed — a lost card becomes a duplicated one.
  s.piles[2] = [];
  const before = JSON.stringify(s);
  T.undo();
  assert.equal(JSON.stringify(T.state()), before, "undo must change nothing");
  assert.equal(T.state().queue.filter((x) => x === s.history[0].card).length, 0,
    "the card must not be duplicated into the queue");
});

test("R3 undo does not delete a written card's text", () => {
  const { T } = load();
  const card = T.addCustomCard("belonging", "");
  T.assign(4);
  T.undo();
  assert.equal(T.state().customCards.length, 1);
  assert.equal(T.state().queue[0], "custom:" + card.id);
  assert.deepEqual(T.state().piles[4], []);
});

/* ===========================================================================
   R4 — Custom cards
   ======================================================================== */

test("R4 a written card is uppercased and goes to the front of the queue", () => {
  const { T } = load();
  const before = T.state().queue[0];
  const card = T.addCustomCard("  community  ", "  to belong somewhere  ");
  assert.equal(card.name, "COMMUNITY");
  assert.equal(card.descriptor, "to belong somewhere");
  assert.equal(T.state().queue[0], "custom:" + card.id);
  assert.equal(T.state().queue[1], before);
});

test("R4 a blank descriptor falls back to the default gloss", () => {
  const { T } = load();
  assert.equal(T.addCustomCard("resolve", "").descriptor, "a value I wrote myself");
  assert.equal(T.addCustomCard("nerve", "   ").descriptor, "a value I wrote myself");
});

test("R4 a blank name is refused", () => {
  const { T } = load();
  const n = T.state().queue.length;
  assert.equal(T.addCustomCard("", "something"), null);
  assert.equal(T.addCustomCard("   ", "something"), null);
  assert.equal(T.state().queue.length, n);
  assert.equal(T.state().customCards.length, 0);
});

test("R4 several written cards stack newest-first", () => {
  const { T } = load();
  const a = T.addCustomCard("first", "");
  const b = T.addCustomCard("second", "");
  assert.equal(T.state().queue[0], "custom:" + b.id);
  assert.equal(T.state().queue[1], "custom:" + a.id);
});

test("R4 a card can be written after the queue empties", () => {
  const { T } = load();
  sortAll(T, 6);
  assert.equal(T.state().queue.length, 0);
  const card = T.addCustomCard("afterthought", "");
  assert.equal(T.state().queue[0], "custom:" + card.id);
});

/* ===========================================================================
   R5 / R6 — Cull and promotion
   ======================================================================== */

test("R5 the kept set is Most important minus the cuts", () => {
  const { T } = load();
  sortAll(T, 12);
  T.go("cull");
  const top = T.state().piles[4].slice();
  T.draft().cut.push(top[0], top[1]);
  assert.deepEqual(T.keptIDs(), top.slice(2));
});

test("R5 cull refuses to finish outside the 5-10 band", () => {
  const { T } = load();
  sortAll(T, 12);
  T.go("cull");
  T.finishCull();                                    // 12 kept — too many
  assert.equal(T.state().phase, "cull");
  T.draft().cut.push(...T.state().piles[4].slice(0, 8));   // 4 kept — too few
  T.finishCull();
  assert.equal(T.state().phase, "cull");
});

test("R6 promotion order is preserved into the kept set", () => {
  const { T } = load();
  sortAll(T, 12);
  T.go("cull");
  const top = T.state().piles[4].slice();
  const veryImportant = T.state().piles[3].slice();
  T.draft().cut.push(...top.slice(0, 9));            // 3 left

  /* Promote in the order that sorting would NOT produce, so "kept order equals
     promotion order" is distinguishable from "kept order is any stable order".
     Picking two arbitrary ids leaves it to chance whether their click order
     already matches their sorted order, and mutation M6 slipped through the
     half of the time that it did. */
  const pair = [veryImportant[5], veryImportant[1]].sort();
  T.draft().promotions.push(pair[1], pair[0]);
  assert.deepEqual(T.keptIDs(), [...top.slice(9), pair[1], pair[0]]);
});

test("R6 finishing cull moves cuts down and promotions up, conserving cards", () => {
  const { T, deck } = load();
  sortAll(T, 12);
  T.go("cull");
  const top = T.state().piles[4].slice();
  const vi = T.state().piles[3].slice();
  T.draft().cut.push(...top.slice(0, 9));
  T.draft().promotions.push(vi[0], vi[1]);
  T.finishCull();
  const s = T.state();
  assert.equal(s.phase, "rank");
  assert.equal(s.ranking.length, 5);
  assert.deepEqual(s.piles[4], s.ranking);
  assert.ok(s.cut.every((id) => s.piles[3].includes(id)), "cuts drop to Very important");
  assert.ok(s.promotions.every((id) => s.piles[4].includes(id)), "promotions rise");
  assert.equal(s.piles.flat().length, deck.cardCount);
  assert.equal(new Set(s.piles.flat()).size, deck.cardCount);
});

/* ===========================================================================
   R7 — Rank
   ======================================================================== */

function toRank(T, keep = 6) {
  sortAll(T, 12);
  T.go("cull");
  T.draft().cut.push(...T.state().piles[4].slice(0, 12 - keep));
  T.finishCull();
}

test("R7 moving swaps adjacent entries and leaves the rest alone", () => {
  const { T } = load();
  toRank(T);
  const before = T.state().ranking.slice();
  T.move(2, 1);
  const after = T.state().ranking;
  assert.equal(after[2], before[3]);
  assert.equal(after[3], before[2]);
  assert.deepEqual(after.slice(0, 2), before.slice(0, 2));
  assert.deepEqual(after.slice(4), before.slice(4));
});

test("R7 moving past either end is a no-op", () => {
  const { T } = load();
  toRank(T);
  const before = T.state().ranking.slice();
  T.move(0, -1);
  T.move(before.length - 1, 1);
  assert.deepEqual(T.state().ranking, before);
});

test("R7 ranking is a permutation of the kept set", () => {
  const { T } = load();
  toRank(T);
  const kept = T.state().ranking.slice();
  for (let i = 0; i < 20; i++) T.move(i % (kept.length - 1), 1);
  assert.deepEqual(new Set(T.state().ranking), new Set(kept));
  assert.equal(T.state().ranking.length, kept.length);
});

/* ===========================================================================
   R8 — Export
   ======================================================================== */

/* The five pile labels are pinned HERE, literally, and not read from the page.
   They are contract (SPEC §5.2 R2) and they appear verbatim in exports people
   have already saved, so rewording one silently changes their documents. A
   test that looped over the page's own PILES array would compare the code with
   itself and pass whatever it said — which is exactly what mutation M13 caught
   it doing. */
const CONTRACT_PILES = [
  "Not important to me",
  "Somewhat important to me",
  "Important to me",
  "Very important to me",
  "Most important to me",
];

test("the five pile labels are the contract ones", () => {
  const { T } = load();
  assert.deepEqual(T.PILES, CONTRACT_PILES);
});

test("R8 markdown carries every pile, the ranking, and the attribution", () => {
  const { T, deck } = load();
  toRank(T);
  T.go("export");
  const md = T.markdown();
  for (const label of CONTRACT_PILES) assert.ok(md.includes("### " + label), label);
  assert.ok(md.includes(deck.instrument.authors));
  assert.ok(md.includes(String(deck.instrument.year)));
  assert.equal((md.match(/^\d+\. \*\*/gm) || []).length, T.state().ranking.length);
});

test("R8 the export drops the #AI/Claude tag the reference emits (O2)", () => {
  const { T } = load();
  toRank(T);
  T.go("export");
  assert.ok(!T.markdown().includes("#AI/Claude"));
});

test("R8 the export date is completion time, not render time (D4)", () => {
  const { T } = load();
  toRank(T);
  T.go("export");
  assert.equal(typeof T.state().completedAt, "number");

  /* Stamp a sentinel no clock could produce, then leave and come back. Reading
     the real timestamp and comparing it would pass whether or not the guard is
     there, because both visits land in the same millisecond — mutation M8
     survived on exactly that. */
  T.state().completedAt = 1;
  T.go("rank");
  T.go("export");
  assert.equal(T.state().completedAt, 1, "re-entering export must not re-date the sort");
});

test("R8 an empty pile prints as (empty) rather than vanishing", () => {
  const { T } = load();
  sortAll(T, 12);                        // nothing ever goes to pile index 4%4=0? guard below
  T.go("cull");
  T.draft().cut.push(...T.state().piles[4].slice(0, 6));
  T.finishCull();
  T.go("export");
  const md = T.markdown();
  const empties = T.state().piles.filter((p) => p.length === 0).length;
  assert.equal((md.match(/_\(empty\)_/g) || []).length, empties);
});

test("R8 the JSON download is the native SessionState schema", () => {
  const { T } = load();
  toRank(T);
  T.addCustomCard("community", "to belong somewhere");
  T.go("export");
  const j = JSON.parse(T.sessionJSON());
  assert.deepEqual(Object.keys(j).sort(), [
    "completedAt", "customCards", "cut", "deckVersion", "history", "id",
    "phase", "piles", "promotions", "queue", "ranking", "shuffleOrder",
    "startedAt", "themeID",
  ]);
  assert.deepEqual(Object.keys(j.customCards[0]).sort(),
    ["createdAt", "descriptor", "id", "name"]);
  assert.match(j.id, /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/);
  assert.equal(typeof j.history[0].pile, "number");
  assert.equal(j.themeID, "note-card");
  // Dates are seconds since the 2001 Apple reference date, as Swift writes them.
  assert.ok(j.startedAt > 750000000 && j.startedAt < 1300000000,
    "startedAt is on the Apple epoch, not the Unix one");
});

/** A fixed session: same cards, same piles, same ranking, every time.
 *
 * R8 is the one rule whose output a person keeps. docs/TESTING.md requires a
 * golden-file comparison for it — "a fixture session -> exact expected
 * markdown" — and the suite shipped without one, asserting only that each pile
 * heading appeared *somewhere*. That is order-blind, and four export mutations
 * survived it: pile order, the top pile using ranked order, the completion
 * date line, and the descriptor in the full-sort lines. */
function fixtureSession() {
  const { T } = load();
  const s = T.state();
  s.queue = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map((n) => "deck:" + n);
  s.shuffleOrder = s.queue.slice();
  s.piles = [[], [], [], [], []];
  s.history = [];
  s.customCards = [];

  const written = T.addCustomCard("COMMUNITY", "to belong somewhere");
  T.assign(4);                                   // the written card, top pile
  [4, 4, 4, 4, 4, 3, 3, 2, 2, 1, 0, 0].forEach((p) => T.assign(p));

  const st = T.state();
  st.ranking = st.piles[4].slice();               // 6 kept
  st.phase = "rank";
  /* Reorder, so `ranking` and `piles[4]` are NOT the same sequence. They are
     identical the instant cull finishes and diverge the moment the sorter
     presses an arrow — so a fixture that skips this cannot tell whether the
     export reads the ranking or the pile, which is the single most damaging
     thing R8 can get wrong. */
  T.move(0, 1);
  T.move(4, -1);
  st.phase = "export";
  st.completedAt = 809827200;                     // fixed instant, not "now"
  return { T, written };
}

test("R8 the markdown export matches the golden file exactly", () => {
  const { T } = fixtureSession();
  const md = T.markdown();

  /* The date is locale- and timezone-formatted by design (D4 says the body is
     locale formatted), so the two date occurrences are masked and asserted
     separately. Everything else — every heading, every line, every ordering —
     is pinned byte for byte. */
  const dateStr = new Date((809827200 + 978307200) * 1000)
    .toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" });
  assert.ok(md.includes("Completed: " + dateStr), "the completion date line is present");

  const masked = md.split(dateStr).join("<DATE>");
  const goldenPath = path.join(__dirname, "golden", "r8-export.md");
  if (process.env.UPDATE_GOLDEN === "1") fs.writeFileSync(goldenPath, masked);
  const expected = fs.readFileSync(goldenPath, "utf8");
  assert.equal(masked, expected);
});

/* ===========================================================================
   Deck contract — the page must not carry its own copy of the instrument
   ======================================================================== */

test("the page's deck is the generated one, matching data/deck.v1.json", () => {
  const { deck } = load();
  const source = JSON.parse(
    fs.readFileSync(path.join(WEB, "..", "data", "deck.v1.json"), "utf8"));
  assert.equal(deck.cardCount, source.cardCount);
  assert.equal(deck.cards.length, source.cards.length);
  source.cards.forEach((c, i) => {
    assert.equal(deck.cards[i].id, c.id);
    assert.equal(deck.cards[i].name, c.name);
    assert.equal(deck.cards[i].descriptor, c.descriptor);
  });
});

test("index.html carries no inline copy of the deck", () => {
  const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
  const source = JSON.parse(
    fs.readFileSync(path.join(WEB, "..", "data", "deck.v1.json"), "utf8"));
  // The reference implementation inlines all 83 cards in a RAW array. If more
  // than a couple of card names appear in the page itself, a second deck has
  // crept back in.
  const inlined = source.cards.filter((c) => html.includes(c.descriptor)).length;
  assert.ok(inlined === 0, `${inlined} card descriptors are inlined in index.html`);
});

/* ===========================================================================
   Privacy — SPEC §7's promise, on this surface
   ======================================================================== */

test("the page touches no storage or network API during a whole session", () => {
  const { T, touched } = load();
  // Exercise every path a user can take, not just construction.
  T.addCustomCard("community", "to belong somewhere");
  let i = 0;
  while (T.state().queue.length) { T.assign(i < 12 ? 4 : i % 4); i++; }
  T.go("cull");
  T.draft().cut.push(...T.state().piles[4].slice(0, 6));
  T.finishCull();
  T.move(0, 1);
  T.go("export");
  T.markdown();
  T.sessionJSON();
  assert.deepEqual(touched, [], `the page touched: ${touched.join(", ")}`);
});

test("the only external URLs are attribution and licence links", () => {
  const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
  const allowed = [
    "https://www.gnu.org/licenses/gpl-3.0.html",
    "https://github.com/martin-gleason/values-card-sort",
  ];
  const urls = [...html.matchAll(/https?:\/\/[^"'\s)]+/g)].map((m) => m[0]);
  for (const u of urls) {
    assert.ok(allowed.includes(u), `unexpected external URL in the page: ${u}`);
  }
  // No external subresources at all: every src/href that loads something must
  // be same-origin.
  const subresources = [...html.matchAll(/<(?:script|link|img|iframe)[^>]*?(?:src|href)="([^"]+)"/g)]
    .map((m) => m[1]);
  for (const s of subresources) {
    assert.ok(!/^https?:/.test(s), `external subresource: ${s}`);
  }
});
