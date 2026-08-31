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
    const page = await browser.newPage();
    await page.setViewport({ width: 1024, height: 900, deviceScaleFactor: 2 });
    await page.goto(base, { waitUntil: "load" });
    // beforeunload must never interrupt an automated run.
    page.on("dialog", (d) => d.accept());
    await page.evaluate(state.drive);
    await page.evaluate(axeSource);

    const results = await page.evaluate(async (tags) => {
      const r = await window.axe.run(document, { runOnly: { type: "tag", values: tags } });
      return {
        violations: r.violations.map((v) => ({
          id: v.id, impact: v.impact, help: v.help,
          nodes: v.nodes.map((n) => ({ target: n.target.join(" "), summary: n.failureSummary })),
        })),
        passes: r.passes.length,
        incomplete: r.incomplete.map((i) => i.id),
        /* axe reports "incomplete" when it cannot decide — most often contrast
           over a background image or a partly transparent stack. Those are not
           passes, and under D5 they cannot be shrugged off, so the gate prints
           what it could not measure and against which colours. */
        incompleteDetail: r.incomplete.flatMap((i) =>
          i.nodes.map((n) => ({
            rule: i.id,
            target: n.target.join(" "),
            reason: (n.any[0] && n.any[0].message) || "",
            fg: (n.any[0] && n.any[0].data && n.any[0].data.fgColor) || null,
            bg: (n.any[0] && n.any[0].data && n.any[0].data.bgColor) || null,
            ratio: (n.any[0] && n.any[0].data && n.any[0].data.contrastRatio) || null,
          }))),
      };
    }, TAGS);

    const n = results.violations.length;
    totalViolations += n;
    const mark = n === 0 ? "  ok  " : "  FAIL";
    console.log(`${mark} ${state.name.padEnd(18)} ${String(results.passes).padStart(3)} rules passed` +
                (n ? `, ${n} VIOLATION(S)` : "") +
                (results.incomplete.length ? `  [needs review: ${results.incomplete.join(", ")}]` : ""));

    for (const v of results.violations) {
      console.log(`         ${v.id} (${v.impact}) — ${v.help}`);
      for (const node of v.nodes.slice(0, 4)) {
        console.log(`           ${node.target}`);
        if (node.summary) {
          console.log(node.summary.split("\n").map((l) => "             " + l.trim()).join("\n"));
        }
      }
    }

    for (const d of results.incompleteDetail) {
      console.log(`         ? ${d.rule} ${d.target}` +
                  (d.fg ? `  fg=${d.fg} bg=${d.bg} ratio=${d.ratio}` : "") +
                  `\n           ${d.reason}`);
    }

    report.push({ state: state.name, label: state.label, ...results });

    if (evidenceDir) {
      await page.screenshot({ path: path.join(evidenceDir, `${state.name}.png`), fullPage: true });
    }
    await page.close();
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
    console.log(`FAILED — ${totalViolations} violation(s) across ${STATES.length} states.`);
    console.log("        D5 admits no exemptions: fix the view, never waive the rule.");
    process.exit(1);
  }
  console.log(`PASSED — 0 violations across ${STATES.length} states (WCAG 2.2 AA).`);
}

main().catch((e) => { console.error(e); process.exit(1); });
