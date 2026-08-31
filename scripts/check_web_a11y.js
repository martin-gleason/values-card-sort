// SPDX-License-Identifier: GPL-3.0-or-later
//
// Accessibility gate for the web port — WCAG 2.2 AA, no exemptions.
//
// The web analogue of D5. The native side's rule is absolute: every audit rule,
// every screen, fix the view and never waive the rule. This does the same job
// on this surface, and it does it by *executing* — the plan's own words are
// that a promise which is not executed is not a gate, and this repository has
// been bitten by exactly that twice.
//
// Every phase is audited, including the two states that only exist
// transiently: the write-your-own-card form and the reset confirmation dialog.
// A gate that only ever sees the first screen is not a gate either.
//
// puppeteer-core drives the system Chrome rather than downloading its own —
// GitHub's runners ship Chrome, and a 300MB download per CI run to audit two
// files would be an absurd trade. axe-core and puppeteer-core are CI
// dev-dependencies; neither is shipped to the browser.
//
//   node scripts/check_web_a11y.js
//   node scripts/check_web_a11y.js --evidence docs/evidence/web

const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const puppeteer = require("puppeteer-core");

const ROOT = path.join(__dirname, "..");
const WEB = path.join(ROOT, "web");
const AXE = require.resolve("axe-core/axe.min.js");

const CHROME_CANDIDATES = [
  process.env.CHROME_PATH,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/usr/bin/google-chrome",
  "/usr/bin/google-chrome-stable",
  "/usr/bin/chromium-browser",
  "/usr/bin/chromium",
].filter(Boolean);

function findChrome() {
  for (const p of CHROME_CANDIDATES) if (fs.existsSync(p)) return p;
  throw new Error(
    "No Chrome found. Set CHROME_PATH, or install Chrome/Chromium.\n" +
    "Tried:\n  " + CHROME_CANDIDATES.join("\n  "));
}

const MIME = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json" };

function serve() {
  const server = http.createServer((req, res) => {
    const rel = decodeURIComponent(req.url.split("?")[0]);
    const file = path.join(WEB, rel === "/" ? "index.html" : rel);
    if (!file.startsWith(WEB) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "text/plain" });
    res.end(fs.readFileSync(file));
  });
  return new Promise((r) => server.listen(0, "127.0.0.1", () => r(server)));
}

/* The states to audit. Each `drive` runs inside the page and leaves the app in
   the state to be checked. They use the app's own verbs, so an audited state
   is one the instrument can actually reach. */
const STATES = [
  { name: "1-sort", label: "Sort — a card on the desk",
    drive: () => {} },
  { name: "2-sort-add-card", label: "Sort — write your own card",
    drive: () => { document.getElementById("btn-add").click(); } },
  { name: "3-sort-complete", label: "Sort — queue empty interstitial",
    drive: () => { const T = VCS_TEST; let i = 0;
      while (T.state().queue.length) { T.assign(i < 12 ? 4 : i % 4); i++; } } },
  { name: "4-cull", label: "Cull — choose 5 to 10",
    drive: () => { const T = VCS_TEST; let i = 0;
      while (T.state().queue.length) { T.assign(i < 12 ? 4 : i % 4); i++; }
      T.go("cull"); } },
  { name: "5-cull-promote", label: "Cull — promotion offered (R6)",
    drive: () => { const T = VCS_TEST; let i = 0;
      while (T.state().queue.length) { T.assign(i < 12 ? 4 : i % 4); i++; }
      T.go("cull");
      document.querySelectorAll("#cull-list button").forEach((b, n) => { if (n < 10) b.click(); }); } },
  { name: "6-rank", label: "Rank — order the kept values",
    drive: () => { const T = VCS_TEST; let i = 0;
      while (T.state().queue.length) { T.assign(i < 12 ? 4 : i % 4); i++; }
      T.go("cull");
      T.draft().cut.push(...T.state().piles[4].slice(0, 6));
      T.finishCull(); } },
  { name: "7-export", label: "Export — results, markdown, downloads",
    drive: () => { const T = VCS_TEST; let i = 0;
      while (T.state().queue.length) { T.assign(i < 12 ? 4 : i % 4); i++; }
      T.go("cull");
      T.draft().cut.push(...T.state().piles[4].slice(0, 6));
      T.finishCull(); T.go("export"); } },
  /* R4 lets the sorter write ANY name, and an unbroken long word has no break
     opportunity. This is the deterministic worst case for WCAG 1.4.10, and it
     is a real user input rather than a contrivance: without the wrap rules on
     .item, this state renders 639px of content in a 320px viewport. The deck's
     own longest names do not trigger it, so relying on a random shuffle to
     surface it made the gate a coin toss. */
  { name: "9-rank-unbreakable-name", label: "Rank — a written card with a long unbroken name (R4 + 1.4.10)",
    drive: () => { const T = VCS_TEST;
      const c1 = T.addCustomCard("SELFDETERMINATIONANDPERSONALSOVEREIGNTY", "to decide the whole course of my own life without asking");
      const c2 = T.addCustomCard("INTERGENERATIONALRESPONSIBILITY", "to leave things better than I found them");
      while (T.state().queue.length) T.assign(4);
      const s = T.state();
      s.ranking = ["custom:" + c1.id, "custom:" + c2.id, ...s.piles[4].slice(0, 4)];
      s.piles[4] = s.ranking.slice();
      T.go("rank"); } },

  { name: "8-reset-dialog", label: "Export — start-over confirmation (R9)",
    drive: () => { const T = VCS_TEST; let i = 0;
      while (T.state().queue.length) { T.assign(i < 12 ? 4 : i % 4); i++; }
      T.go("cull");
      T.draft().cut.push(...T.state().piles[4].slice(0, 6));
      T.finishCull(); T.go("export");
      document.getElementById("btn-reset").click(); } },
];

/* WCAG 2.2 AA in full. No rule is disabled and no state is skipped — that is
   what "no exemptions" has to mean to be worth writing down. */
const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];

/* Every state is audited at both widths. 320 CSS px is the width WCAG 1.4.10
   Reflow names, and it is not optional here: the first version of this gate
   audited only 1024x900 and could not see that a long card name pushed the
   rank screen's move buttons 27px past the viewport. A gate that only ever
   sees a desktop is the same mistake as one that only ever sees one screen. */
const VIEWPORTS = [
  { name: "desktop", width: 1024, height: 900 },
  { name: "narrow", width: 320, height: 800 },
];

/* axe returns `incomplete` — not `violation` — when it cannot resolve a
   background, and the first version of this gate counted only violations. A
   real 3.34:1 failure hid there for exactly that reason.
 *
 * So incomplete now FAILS, unless the case is listed here with a ratio that
 * was computed by hand. That keeps "no exemptions" honest: a NEW incomplete,
 * on any element, fails the build and has to be measured before it can pass. */
const REVIEWED_INCOMPLETE = [
  { rule: "color-contrast", reason: /background gradient/i,
    note: "card face: --ink on --rule #C9DEE9 = 9.62:1; --accent-ink on it = 4.56:1" },
  { rule: "color-contrast", reason: /only non-text characters/i,
    note: "rank move glyphs: --ink on #FFF = 13.36:1" },
  { rule: "color-contrast", reason: /partially overlaps other elements/i,
    note: "dialog body over ::backdrop: --ink on --paper = 13.00:1" },
];

function isReviewed(d) {
  return REVIEWED_INCOMPLETE.some((r) => r.rule === d.rule && r.reason.test(d.reason || ""));
}

async function main() {
  const evidenceIdx = process.argv.indexOf("--evidence");
  const evidenceDir = evidenceIdx > -1 ? path.resolve(process.argv[evidenceIdx + 1]) : null;
  if (evidenceDir) fs.mkdirSync(evidenceDir, { recursive: true });

  const server = await serve();
  const base = `http://127.0.0.1:${server.address().port}/index.html`;
  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    args: ["--no-sandbox", "--disable-dev-shm-usage"],
  });

  const axeSource = fs.readFileSync(AXE, "utf8");
  let totalViolations = 0;
  const report = [];

  console.log("Accessibility gate — WCAG 2.2 AA, no exemptions (the web D5)\n");

  for (const state of STATES) {
    for (const vp of VIEWPORTS) {
      const page = await browser.newPage();
      await page.setViewport({ width: vp.width, height: vp.height, deviceScaleFactor: 2 });
      // Reduce Motion is a SPEC §6 requirement and the CSS honours it; emulate
      // it so there is evidence rather than an untested media query.
      await page.emulateMediaFeatures([
        { name: "prefers-reduced-motion", value: "reduce" },
      ]);
      await page.goto(base, { waitUntil: "load" });
      page.on("dialog", (d) => d.accept());
      await page.evaluate(state.drive);
      await page.evaluate(axeSource);

      const results = await page.evaluate(async (tags) => {
        const r = await window.axe.run(document, { runOnly: { type: "tag", values: tags } });
        const de = document.documentElement;
        return {
          violations: r.violations.map((v) => ({
            id: v.id, impact: v.impact, help: v.help,
            nodes: v.nodes.map((n) => ({ target: n.target.join(" "), summary: n.failureSummary })),
          })),
          passes: r.passes.length,
          incompleteDetail: r.incomplete.flatMap((i) =>
            i.nodes.map((n) => ({
              rule: i.id,
              target: n.target.join(" "),
              reason: (n.any[0] && n.any[0].message) || "",
            }))),
          // WCAG 1.4.10 Reflow: no two-dimensional scrolling at 320 CSS px.
          scrollWidth: de.scrollWidth,
          clientWidth: de.clientWidth,
          overflowing: [...document.querySelectorAll("body *")]
            .filter((el) => el.getBoundingClientRect().right > de.clientWidth + 1)
            .slice(0, 5)
            .map((el) => `${el.tagName}.${el.className || ""} right=${Math.round(el.getBoundingClientRect().right)}`),
        };
      }, TAGS);

      const unreviewed = results.incompleteDetail.filter((d) => !isReviewed(d));
      const reflow = results.scrollWidth > results.clientWidth + 1;
      const n = results.violations.length + unreviewed.length + (reflow ? 1 : 0);
      totalViolations += n;

      const label = `${state.name} @${vp.name}`;
      console.log(`  ${n === 0 ? "ok  " : "FAIL"} ${label.padEnd(30)} ${String(results.passes).padStart(3)} rules passed` +
                  (n ? `, ${n} FAILURE(S)` : ""));

      for (const v of results.violations) {
        console.log(`         ${v.id} (${v.impact}) — ${v.help}`);
        for (const node of v.nodes.slice(0, 3)) console.log(`           ${node.target}`);
      }
      if (reflow) {
        console.log(`         WCAG 1.4.10 Reflow: content is ${results.scrollWidth}px wide in a ${results.clientWidth}px viewport`);
        for (const o of results.overflowing) console.log(`           overflowing: ${o}`);
      }
      for (const d of unreviewed) {
        console.log(`         UNREVIEWED incomplete: ${d.rule} ${d.target}`);
        console.log(`           ${d.reason}`);
        console.log(`           axe could not decide. Compute the ratio by hand and add it to`);
        console.log(`           REVIEWED_INCOMPLETE, or fix the element. Incomplete is not a pass.`);
      }

      report.push({ state: state.name, viewport: vp.name, label: state.label, reflow, ...results });

      if (evidenceDir && vp.name === "desktop") {
        await page.screenshot({ path: path.join(evidenceDir, `${state.name}.png`), fullPage: true });
      }
      await page.close();
    }
  }

  await browser.close();
  server.close();

  if (evidenceDir) {
    fs.writeFileSync(path.join(evidenceDir, "axe-report.json"),
      JSON.stringify({ tags: TAGS, axe: require("axe-core/package.json").version, report }, null, 2));
    console.log(`\nEvidence written to ${path.relative(ROOT, evidenceDir)}/`);
  }

  console.log();
  if (totalViolations) {
    console.log(`FAILED — ${totalViolations} failure(s) across ${STATES.length} states x ${VIEWPORTS.length} viewports.`);
    console.log("        D5 admits no exemptions: fix the view, never waive the rule.");
    process.exit(1);
  }
  console.log(`PASSED — 0 failures across ${STATES.length} states x ${VIEWPORTS.length} viewports (WCAG 2.2 AA, Reduce Motion on).`);
}

main().catch((e) => { console.error(e); process.exit(1); });
