// SPDX-License-Identifier: GPL-3.0-or-later
//
// Keyboard-only traversal of a complete sort — R11, and WCAG 2.1.1.
//
// The plan asks for "a keyboard-only traversal of a complete sort" beside the
// axe run, and it is a separate thing from what axe checks: axe verifies that
// controls have accessible names and are focusable, but it never presses a
// key, so it cannot tell you whether the instrument can actually be *completed*
// without a pointer.
//
// Everything below is done with real, trusted key events through CDP. The mouse
// is never used. If a step here needs a click, the page has failed 2.1.1.
//
//   node scripts/check_web_keyboard.js

const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const puppeteer = require("puppeteer-core");

const ROOT = path.join(__dirname, "..");
const WEB = path.join(ROOT, "web");
const MIME = { ".html": "text/html", ".js": "text/javascript" };

const CHROME = [
  process.env.CHROME_PATH,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/usr/bin/google-chrome",
  "/usr/bin/google-chrome-stable",
  "/usr/bin/chromium-browser",
  "/usr/bin/chromium",
].filter(Boolean).find((p) => fs.existsSync(p));

function serve() {
  const s = http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split("?")[0]);
    const f = path.join(WEB, rel === "/" ? "index.html" : rel);
    if (!f.startsWith(WEB) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { "Content-Type": MIME[path.extname(f)] || "text/plain" });
    res.end(fs.readFileSync(f));
  });
  return new Promise((r) => s.listen(0, "127.0.0.1", () => r(s)));
}

const checks = [];
function check(ok, label, detail) {
  checks.push({ ok, label });
  console.log(`  ${ok ? "ok  " : "FAIL"} ${label}${detail && !ok ? `\n         ${detail}` : ""}`);
}

/** Tabs forward until `predicate` matches the focused element, or gives up. */
async function tabTo(page, predicate, limit = 40) {
  for (let i = 0; i < limit; i++) {
    await page.keyboard.press("Tab");
    const hit = await page.evaluate((p) => {
      const el = document.activeElement;
      if (!el) return null;
      const name = (el.getAttribute("aria-label") || el.textContent || "").trim();
      /* `return (${p})` yields the arrow function itself — an object, and
         therefore always truthy — so every tabTo used to match on the first
         Tab, which is the skip link. Enter then jumped focus to #main and four
         downstream checks failed against a page that was behaving correctly.
         Call it. */
      // eslint-disable-next-line no-new-func
      const match = new Function("name", "el", `return (${p})(name, el);`);
      return match(name, el) ? name : null;
    }, predicate.toString());
    if (hit !== null) return hit;
  }
  return null;
}

async function main() {
  if (!CHROME) throw new Error("No Chrome found; set CHROME_PATH.");
  const server = await serve();
  const url = `http://127.0.0.1:${server.address().port}/index.html`;
  const browser = await puppeteer.launch({
    executablePath: CHROME, args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });
  const page = await browser.newPage();
  page.on("dialog", (d) => d.accept());
  await page.goto(url, { waitUntil: "load" });
  await page.bringToFront();

  console.log("Keyboard-only traversal — R11 and WCAG 2.1.1 (no pointer is used)\n");

  const st = () => page.evaluate(() => {
    const T = window.VCS_TEST, s = T.state();
    return {
      phase: s.phase, history: s.history.length, queue: s.queue.length,
      piles: s.piles.map((p) => p.length), ranking: s.ranking.slice(),
      announced: document.getElementById("status").textContent,
      customs: s.customCards.length,
    };
  });

  /* --- R11: the digit keys sort ---------------------------------------- */
  await page.keyboard.press("3");
  let s = await st();
  check(s.history === 1 && s.piles[2] === 1,
    "R11 pressing 3 sorts the card into Important to me",
    `history=${s.history} piles=${s.piles}`);
  check(/sorted into Important to me/.test(s.announced),
    "the placement is announced to a screen reader", s.announced);

  await page.keyboard.press("5");
  await page.keyboard.press("1");
  s = await st();
  check(s.history === 3 && s.piles[4] === 1 && s.piles[0] === 1,
    "R11 keys 1-5 each reach their own pile", `piles=${s.piles}`);

  /* --- R11: U undoes ---------------------------------------------------- */
  await page.keyboard.press("u");
  s = await st();
  check(s.history === 2 && s.piles[0] === 0,
    "R11 pressing U undoes the last placement", `history=${s.history} piles=${s.piles}`);
  check(/taken back out of/.test(s.announced), "the undo is announced", s.announced);

  /* --- R4 by keyboard alone -------------------------------------------- */
  const addBtn = await tabTo(page, (name) => /Write your own card/.test(name));
  check(addBtn !== null, "the write-your-own-card button is reachable by Tab");
  await page.keyboard.press("Enter");
  const focused = await page.evaluate(() => document.activeElement.id);
  check(focused === "new-name", "opening the form moves focus into the name field", focused);

  await page.keyboard.type("community");
  await page.keyboard.press("Tab");
  await page.keyboard.type("to belong somewhere");
  await page.keyboard.press("Enter");            // submit the form
  s = await st();
  check(s.customs === 1, "R4 a card can be written with the keyboard alone");
  const card = await page.evaluate(() => document.getElementById("card-name").textContent);
  check(card === "COMMUNITY", "R4 the written card is next in the queue", card);

  /* Digits must not be swallowed while typing — checked by the fact that
     "community" arrived intact rather than sorting cards as it was typed. */
  check(s.history === 2, "digits typed into the form did not sort anything");

  /* --- Complete the sort with the keyboard ------------------------------ */
  await page.evaluate(() => document.body.focus());
  for (let i = 0; s.queue > 0 && i < 200; i++) {
    await page.keyboard.press(String((i % 5) + 1));
    s = await st();
  }
  check(s.queue === 0 && s.history === 84,
    "the whole deck sorts by keypress alone", `queue=${s.queue} history=${s.history}`);

  /* --- Through the interstitial into cull ------------------------------- */
  const cont = await tabTo(page, (name) => /^Continue$/.test(name));
  check(cont !== null, "the Continue button is reachable by Tab from the interstitial");
  await page.keyboard.press("Enter");
  s = await st();
  check(s.phase === "cull", "R5 cull is entered by keyboard", s.phase);

  /* --- Cull down to the band -------------------------------------------- */
  const top = (await st()).piles[4];
  let cuts = 0;
  for (let i = 0; i < 60 && cuts < top - 6; i++) {
    const name = await tabTo(page, (n) => /Kept\. Choose to cut it\./.test(n), 3);
    if (name === null) continue;
    await page.keyboard.press("Enter");
    cuts++;
  }
  s = await st();
  const kept = await page.evaluate(() => window.VCS_TEST.keptIDs().length);
  check(kept >= 5 && kept <= 10, `R5 cards can be cut by keyboard (kept ${kept})`);

  const toRank = await tabTo(page, (n) => /Continue to ranking/.test(n));
  check(toRank !== null, "Continue to ranking is reachable by Tab");
  await page.keyboard.press("Enter");
  s = await st();
  check(s.phase === "rank", "R7 rank is entered by keyboard", s.phase);

  /* --- Reorder by keyboard ---------------------------------------------- */
  const before = (await st()).ranking.slice();
  const mover = await tabTo(page, (n) => /^Move .* down/.test(n));
  check(mover !== null, "a rank move button is reachable by Tab", String(mover));
  await page.keyboard.press("Enter");
  s = await st();
  check(JSON.stringify(s.ranking) !== JSON.stringify(before),
    "R7 the ranking can be reordered by keyboard");
  /* The list is rebuilt from scratch after every move, so the button that was
     pressed no longer exists. Focus must land somewhere useful rather than on
     <body>, or a keyboard user is thrown back to the top of the page on each
     press. */
  const stillFocused = await page.evaluate(() => {
    const el = document.activeElement;
    return (el.getAttribute && el.getAttribute("aria-label")) || el.tagName;
  });
  check(/^Move /.test(stillFocused),
    "focus survives the re-render after a rank move", stillFocused);

  /* --- Finish ------------------------------------------------------------ */
  const finish = await tabTo(page, (n) => /^Finish$/.test(n));
  check(finish !== null, "Finish is reachable by Tab");
  await page.keyboard.press("Enter");
  s = await st();
  check(s.phase === "export", "R8 export is reached by keyboard alone", s.phase);

  /* --- R9 the reset dialog is operable and dismissible ------------------- */
  const reset = await tabTo(page, (n) => /Start over/.test(n));
  check(reset !== null, "Start over is reachable by Tab");
  await page.keyboard.press("Enter");
  const dlgOpen = await page.evaluate(() => document.getElementById("reset-dialog").open);
  check(dlgOpen === true, "R9 the confirmation dialog opens");
  await page.keyboard.press("Escape");
  const dlgClosed = await page.evaluate(() => !document.getElementById("reset-dialog").open);
  check(dlgClosed, "R9 Escape dismisses the dialog without destroying the sort");
  s = await st();
  check(s.phase === "export" && s.history === 84,
    "the sort survived the cancelled reset", `phase=${s.phase} history=${s.history}`);

  await browser.close();
  server.close();

  const failed = checks.filter((c) => !c.ok).length;
  console.log();
  if (failed) {
    console.log(`FAILED — ${failed} of ${checks.length} keyboard checks failed.`);
    process.exit(1);
  }
  console.log(`PASSED — all ${checks.length} keyboard checks, no pointer used.`);
}

main().catch((e) => { console.error(e); process.exit(1); });
