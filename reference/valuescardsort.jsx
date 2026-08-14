import { useState, useEffect, useMemo } from "react";

const RAW = [
["ACCEPTANCE","to be accepted as I am"],
["ACCURACY","to be accurate in my opinions and beliefs"],
["ACHIEVEMENT","to have important accomplishments"],
["ADVENTURE","to have new and exciting experiences"],
["ATTRACTIVENESS","to be physically attractive"],
["AUTHORITY","to be in charge of and responsible for others"],
["AUTONOMY","to be self-determined and independent"],
["BEAUTY","to appreciate beauty around me"],
["CARING","to take care of others"],
["CHALLENGE","to take on difficult tasks and problems"],
["CHANGE","to have a life full of change and variety"],
["COMFORT","to have a pleasant and comfortable life"],
["COMMITMENT","to make enduring, meaningful commitments"],
["COMPASSION","to feel and act on concern for others"],
["CONTRIBUTION","to make a lasting contribution in the world"],
["COOPERATION","to work collaboratively with others"],
["COURTESY","to be considerate and polite toward others"],
["CREATIVITY","to have new and original ideas"],
["DEPENDABILITY","to be reliable and trustworthy"],
["DUTY","to carry out my duties and obligations"],
["ECOLOGY","to live in harmony with the environment"],
["EXCITEMENT","to have a life full of thrills and stimulation"],
["FAITHFULNESS","to be loyal and true in relationships"],
["FAME","to be known and recognized"],
["FAMILY","to have a happy, loving family"],
["FITNESS","to be physically fit and strong"],
["FLEXIBILITY","to adjust to new circumstances easily"],
["FORGIVENESS","to be forgiving of others"],
["FRIENDSHIP","to have close, supportive friends"],
["FUN","to play and have fun"],
["GENEROSITY","to give what I have to others"],
["GENUINENESS","to act in a manner that is true to who I am"],
["GOD'S WILL","to seek and obey the will of God"],
["GROWTH","to keep changing and growing"],
["HEALTH","to be physically well and healthy"],
["HELPFULNESS","to be helpful to others"],
["HONESTY","to be honest and truthful"],
["HOPE","to maintain a positive and optimistic outlook"],
["HUMILITY","to be modest and unassuming"],
["HUMOR","to see the humorous side of myself and the world"],
["INDEPENDENCE","to be free from dependence on others"],
["INDUSTRY","to work hard and well at my life tasks"],
["INNER PEACE","to experience personal peace"],
["INTIMACY","to share my innermost experiences with others"],
["JUSTICE","to promote fair and equal treatment for all"],
["KNOWLEDGE","to learn and contribute valuable knowledge"],
["LEISURE","to take time to relax and enjoy"],
["LOVED","to be loved by those close to me"],
["LOVING","to give love to others"],
["MASTERY","to be competent in my everyday activities"],
["MINDFULNESS","to live conscious and mindful of the present moment"],
["MODERATION","to avoid excesses and find a middle ground"],
["MONOGAMY","to have one close, loving relationship"],
["NON-CONFORMITY","to question and challenge authority and norms"],
["NURTURANCE","to take care of and nurture others"],
["OPENNESS","to be open to new experiences, ideas, and options"],
["ORDER","to have a life that is well-ordered and organized"],
["PASSION","to have deep feelings about ideas, activities, or people"],
["PLEASURE","to feel good"],
["POPULARITY","to be well-liked by many people"],
["POWER","to have control over others"],
["PURPOSE","to have meaning and direction in my life"],
["RATIONALITY","to be guided by reason and logic"],
["REALISM","to see and act realistically and practically"],
["RESPONSIBILITY","to make and carry out responsible decisions"],
["RISK","to take risks and chances"],
["ROMANCE","to have intense, exciting love in my life"],
["SAFETY","to be safe and secure"],
["SELF-ACCEPTANCE","to accept myself as I am"],
["SELF-CONTROL","to be disciplined in my own actions"],
["SELF-ESTEEM","to feel good about myself"],
["SELF-KNOWLEDGE","to have a deep and honest understanding of myself"],
["SERVICE","to be of service to others"],
["SEXUALITY","to have an active and satisfying sex life"],
["SIMPLICITY","to live life simply, with minimal needs"],
["SOLITUDE","to have time and space where I can be apart from others"],
["SPIRITUALITY","to grow and mature spiritually"],
["STABILITY","to have a life that stays fairly consistent"],
["TOLERANCE","to accept and respect those who differ from me"],
["TRADITION","to follow respected patterns of the past"],
["VIRTUE","to live a morally pure and excellent life"],
["WEALTH","to have plenty of money"],
["WORLD PEACE","to work to promote peace in the world"],
];

const DECK = RAW.map((r, i) => ({ id: i + 1, name: r[0], desc: r[1] }));
const PILES = [
  { label: "Not important to me", short: "Not important" },
  { label: "Somewhat important to me", short: "Somewhat important" },
  { label: "Important to me", short: "Important" },
  { label: "Very important to me", short: "Very important" },
  { label: "Most important to me", short: "Most important" },
];
const KEY = "vcs_state_v1";
const FELT = "#20392F";
const PAPER = "#FDFCF6";
const INK = "#25322C";
const RULE = "#C9DEE9";
const REDRULE = "#DB9A93";
const ACCENT = "#C75146";
const CREAM = "#F3EFE4";
const MUTED = "#9BB4A9";
const MONO = "ui-monospace, SFMono-Regular, Menlo, monospace";
const SERIF = "Georgia, 'Times New Roman', serif";

function shuffle(a) {
  const x = [...a];
  for (let i = x.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [x[i], x[j]] = [x[j], x[i]];
  }
  return x;
}
const fresh = () => ({
  queue: shuffle(DECK.map((c) => c.id)),
  piles: [[], [], [], [], []],
  custom: [],
  history: [],
  phase: "sort",
  ranking: [],
});

export default function ValuesCardSort() {
  const [loaded, setLoaded] = useState(false);
  const [queue, setQueue] = useState([]);
  const [piles, setPiles] = useState([[], [], [], [], []]);
  const [custom, setCustom] = useState([]);
  const [history, setHistory] = useState([]);
  const [phase, setPhase] = useState("sort");
  const [ranking, setRanking] = useState([]);
  const [cut, setCut] = useState([]);
  const [promo, setPromo] = useState([]);
  const [showAdd, setShowAdd] = useState(false);
  const [nName, setNName] = useState("");
  const [nDesc, setNDesc] = useState("");
  const [copied, setCopied] = useState(false);

  const cards = useMemo(() => {
    const m = {};
    DECK.forEach((c) => (m[c.id] = c));
    custom.forEach((c) => (m[c.id] = c));
    return m;
  }, [custom]);

  const applyState = (s) => {
    setQueue(s.queue); setPiles(s.piles); setCustom(s.custom);
    setHistory(s.history); setPhase(s.phase); setRanking(s.ranking);
    setCut([]); setPromo([]);
  };

  useEffect(() => {
    (async () => {
      try {
        if (window.storage) {
          const r = await window.storage.get(KEY);
          if (r && r.value) { applyState(JSON.parse(r.value)); setLoaded(true); return; }
        }
      } catch (e) {}
      applyState(fresh()); setLoaded(true);
    })();
  }, []);

  useEffect(() => {
    if (!loaded) return;
    const s = JSON.stringify({ queue, piles, custom, history, phase, ranking });
    (async () => { try { if (window.storage) await window.storage.set(KEY, s); } catch (e) {} })();
  }, [loaded, queue, piles, custom, history, phase, ranking]);

  const assign = (p) => {
    if (!queue.length) return;
    const id = queue[0];
    setPiles((ps) => ps.map((arr, i) => (i === p ? [...arr, id] : arr)));
    setHistory((h) => [...h, { id, p }]);
    setQueue((q) => q.slice(1));
  };
  const undo = () => {
    if (!history.length) return;
    const last = history[history.length - 1];
    setPiles((ps) => ps.map((arr, i) => (i === last.p ? arr.filter((x) => x !== last.id) : arr)));
    setQueue((q) => [last.id, ...q]);
    setHistory((h) => h.slice(0, -1));
  };
  const addCustom = () => {
    const name = nName.trim().toUpperCase();
    if (!name) return;
    const c = { id: "c" + Date.now(), name, desc: nDesc.trim() || "a value I wrote myself" };
    setCustom((cs) => [...cs, c]);
    setQueue((q) => [c.id, ...q]);
    setNName(""); setNDesc(""); setShowAdd(false);
  };
  const reset = async () => {
    if (!window.confirm("Start over? Your entire sort will be erased.")) return;
    try { if (window.storage) await window.storage.delete(KEY); } catch (e) {}
    applyState(fresh());
  };

  useEffect(() => {
    const fn = (e) => {
      if (phase !== "sort" || showAdd) return;
      const t = e.target.tagName;
      if (t === "INPUT" || t === "TEXTAREA") return;
      if (e.key >= "1" && e.key <= "5" && queue.length) assign(Number(e.key) - 1);
      if (e.key === "u" || e.key === "U") undo();
    };
    window.addEventListener("keydown", fn);
    return () => window.removeEventListener("keydown", fn);
  });

  const kept = useMemo(
    () => piles[4].filter((id) => !cut.includes(id)).concat(promo),
    [piles, cut, promo]
  );

  const finishCull = () => {
    if (kept.length < 5 || kept.length > 10) return;
    setPiles((ps) => {
      const p4 = ps[4].filter((id) => !cut.includes(id)).concat(promo);
      const p3 = ps[3].filter((id) => !promo.includes(id)).concat(cut);
      return [ps[0], ps[1], ps[2], p3, p4];
    });
    setRanking(kept);
    setCut([]); setPromo([]);
    setPhase("rank");
  };
  const move = (i, d) => {
    setRanking((r) => {
      const j = i + d;
      if (j < 0 || j >= r.length) return r;
      const x = [...r];
      [x[i], x[j]] = [x[j], x[i]];
      return x;
    });
  };
  const md = useMemo(() => {
    const date = new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" });
    let s = "# Personal Values Card Sort - Results\n\n";
    s += "Instrument: W.R. Miller, J. C'de Baca, D.B. Matthews & P.L. Wilbourne";
    s += " (University of New Mexico, 2001). Public domain.\n";
    s += "Completed: " + date + "\n\n## Top values (ranked)\n\n";
    ranking.forEach((id, i) => {
      const c = cards[id];
      if (c) s += (i + 1) + ". **" + c.name + "** - " + c.desc + "\n";
    });
    s += "\n## Full sort\n";
    for (let p = 4; p >= 0; p--) {
      s += "\n### " + PILES[p].label + "\n\n";
      const ids = p === 4 ? ranking : piles[p];
      if (!ids.length) s += "_(empty)_\n";
      ids.forEach((id) => { const c = cards[id]; if (c) s += "- " + c.name + " - " + c.desc + "\n"; });
    }
    s += "\n-----\n" + date + "\n\n#AI/Claude\n";
    return s;
  }, [ranking, piles, cards]);
  const copy = async () => {
    try { await navigator.clipboard.writeText(md); setCopied(true); }
    catch (e) {
      const t = document.getElementById("vcs-md");
      if (t) { t.select(); try { document.execCommand("copy"); setCopied(true); } catch (e2) {} }
    }
    setTimeout(() => setCopied(false), 2000);
  };

  const IndexCard = ({ name, desc, big }) => (
    <div className="relative rounded-sm shadow-xl w-full"
      style={{ background: PAPER, transform: "rotate(-0.4deg)",
        backgroundImage: "repeating-linear-gradient(to bottom, transparent 0px, transparent 31px, " + RULE + " 31px, " + RULE + " 32px)",
        minHeight: big ? 224 : 0 }}>
      <div className="absolute left-0 right-0" style={{ top: 44, borderTop: "2px solid " + REDRULE }} />
      <div className="relative px-6 pb-6" style={{ paddingTop: 10 }}>
        <div className={big ? "text-2xl" : "text-base"}
          style={{ color: INK, fontWeight: 800, letterSpacing: "0.08em", lineHeight: "32px" }}>
          {name}
        </div>
        <div style={{ color: INK, fontFamily: SERIF, fontStyle: "italic", lineHeight: "32px", marginTop: 4 }}
          className={big ? "text-lg" : "text-sm"}>
          {desc}
        </div>
      </div>
    </div>
  );

  const Btn = ({ onClick, children, primary, disabled, style }) => (
    <button onClick={onClick} disabled={disabled}
      className="rounded px-4 py-2 font-semibold focus:outline-none focus-visible:ring-2 disabled:opacity-40 transition-colors"
      style={{ background: primary ? ACCENT : "rgba(255,255,255,0.08)",
        color: primary ? "#FFF" : CREAM, fontFamily: MONO, fontSize: 13, ...style }}>
      {children}
    </button>
  );

  if (!loaded) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ background: FELT }}>
        <div style={{ color: MUTED, fontFamily: MONO }}>Shuffling the deck...</div>
      </div>
    );
  }

  const total = DECK.length + custom.length;
  const sorted = total - queue.length;
  const cur = queue.length ? cards[queue[0]] : null;

  const phaseNo = { sort: 1, cull: 2, rank: 3, export: 4 }[phase];
  const phaseName = { sort: "SORT THE DECK", cull: "CHOOSE 5-10", rank: "RANK THEM", export: "YOUR CARD" }[phase];

  return (
    <div className="min-h-screen w-full px-4 py-8" style={{ background: FELT }}>
      <div className="mx-auto w-full max-w-2xl">
        <div style={{ color: MUTED, fontFamily: MONO, fontSize: 11, letterSpacing: "0.25em" }}>
          PERSONAL VALUES CARD SORT
        </div>
        <div className="mt-1 mb-6" style={{ color: "rgba(255,255,255,0.45)", fontFamily: SERIF, fontStyle: "italic", fontSize: 13 }}>
          Miller, C'de Baca, Matthews & Wilbourne · University of New Mexico, 2001 · public domain
        </div>
        <div className="flex items-center justify-between mb-4">
          <div style={{ color: CREAM, fontFamily: MONO, fontSize: 12, letterSpacing: "0.15em" }}>
            PHASE {phaseNo} OF 4 · {phaseName}
          </div>
          {phase === "sort" && (
            <div style={{ color: MUTED, fontFamily: MONO, fontSize: 12 }}>{sorted} / {total}</div>
          )}
        </div>
        {phase === "sort" && (
          <div className="h-1 w-full rounded mb-6" style={{ background: "rgba(255,255,255,0.12)" }}>
            <div className="h-1 rounded" style={{ background: ACCENT, width: (total ? (sorted / total) * 100 : 0) + "%" }} />
          </div>
        )}

        {phase === "sort" && cur && !showAdd && (
          <div>
            <IndexCard name={cur.name} desc={cur.desc} big />
            <div className="mt-6 space-y-2">
              {PILES.map((p, i) => (
                <button key={i} onClick={() => assign(i)}
                  className="w-full flex items-center gap-3 rounded px-4 py-3 text-left focus:outline-none focus-visible:ring-2 transition-transform active:scale-95"
                  style={{ background: CREAM, color: INK, borderLeft: i === 4 ? "5px solid " + ACCENT : "5px solid transparent" }}>
                  <span className="flex items-center justify-center rounded-full"
                    style={{ width: 22, height: 22, border: "1px solid " + INK, fontFamily: MONO, fontSize: 11 }}>
                    {i + 1}
                  </span>
                  <span className="flex-1 font-semibold" style={{ fontSize: 15 }}>{p.label}</span>
                  <span style={{ fontFamily: MONO, fontSize: 12, opacity: 0.5 }}>{piles[i].length}</span>
                </button>
              ))}
            </div>
            <div className="mt-4 flex gap-2">
              <Btn onClick={undo} disabled={!history.length}>Undo</Btn>
              <Btn onClick={() => setShowAdd(true)}>+ Write your own card</Btn>
            </div>
            <div className="mt-3" style={{ color: "rgba(255,255,255,0.35)", fontFamily: MONO, fontSize: 11 }}>
              Keyboard: 1-5 to sort · U to undo
            </div>
          </div>
        )}

        {phase === "sort" && showAdd && (
          <div className="rounded-sm shadow-xl px-6 py-6" style={{ background: PAPER }}>
            <div style={{ color: INK, fontWeight: 800, letterSpacing: "0.08em" }}>YOUR OWN VALUE</div>
            <input value={nName} onChange={(e) => setNName(e.target.value)} placeholder="NAME (e.g. COMMUNITY)"
              className="mt-3 w-full rounded border px-3 py-2 focus:outline-none focus-visible:ring-2"
              style={{ borderColor: RULE, color: INK, background: "#FFF" }} autoFocus />
            <input value={nDesc} onChange={(e) => setNDesc(e.target.value)} placeholder="what it means to you"
              className="mt-2 w-full rounded border px-3 py-2 focus:outline-none focus-visible:ring-2"
              style={{ borderColor: RULE, color: INK, background: "#FFF", fontFamily: SERIF, fontStyle: "italic" }} />
            <div className="mt-4 flex gap-2">
              <Btn onClick={addCustom} primary>Add to deck</Btn>
              <Btn onClick={() => setShowAdd(false)}>Cancel</Btn>
            </div>
          </div>
        )}

        {phase === "sort" && !cur && !showAdd && (
          <div>
            <IndexCard name="DECK SORTED" desc={"All " + total + " cards placed. Most important pile: " + piles[4].length + " cards."} big />
            <div className="mt-6 flex flex-wrap gap-2">
              <Btn onClick={() => { setCut([]); setPromo([]); setPhase("cull"); }} primary>Continue</Btn>
              <Btn onClick={undo} disabled={!history.length}>Undo last</Btn>
              <Btn onClick={() => setShowAdd(true)}>+ Add a card</Btn>
            </div>
          </div>
        )}

        {phase === "cull" && (
          <div>
            <div className="mb-4" style={{ color: CREAM, fontFamily: SERIF, fontStyle: "italic" }}>
              Keep your 5 to 10 most important. Tap a card to cut it.
            </div>
            <div className="mb-4" style={{ color: kept.length >= 5 && kept.length <= 10 ? MUTED : ACCENT, fontFamily: MONO, fontSize: 13 }}>
              {kept.length} kept {kept.length > 10 ? "- cut " + (kept.length - 10) + " more" : kept.length < 5 ? "- need " + (5 - kept.length) + " more" : "- ready"}
            </div>
            <div className="space-y-2">
              {piles[4].map((id) => {
                const c = cards[id]; const isCut = cut.includes(id);
                return (
                  <button key={id} onClick={() => setCut((x) => isCut ? x.filter((y) => y !== id) : [...x, id])}
                    className="w-full text-left rounded-sm px-4 py-3 shadow focus:outline-none focus-visible:ring-2"
                    style={{ background: PAPER, opacity: isCut ? 0.35 : 1 }}>
                    <span style={{ color: INK, fontWeight: 800, letterSpacing: "0.06em", textDecoration: isCut ? "line-through" : "none" }}>{c.name}</span>
                    <span className="block text-sm" style={{ color: INK, fontFamily: SERIF, fontStyle: "italic" }}>{c.desc}</span>
                  </button>
                );
              })}
            </div>
            {kept.length < 5 && piles[3].length > 0 && (
              <div className="mt-6">
                <div className="mb-2" style={{ color: CREAM, fontFamily: SERIF, fontStyle: "italic" }}>
                  Short of five - promote from Very important:
                </div>
                <div className="space-y-2">
                  {piles[3].map((id) => {
                    const c = cards[id]; const isP = promo.includes(id);
                    return (
                      <button key={id} onClick={() => setPromo((x) => isP ? x.filter((y) => y !== id) : [...x, id])}
                        className="w-full text-left rounded-sm px-4 py-3 shadow focus:outline-none focus-visible:ring-2"
                        style={{ background: isP ? PAPER : "rgba(253,252,246,0.55)", borderLeft: isP ? "5px solid " + ACCENT : "5px solid transparent" }}>
                        <span style={{ color: INK, fontWeight: 800, letterSpacing: "0.06em" }}>{c.name}</span>
                        <span className="block text-sm" style={{ color: INK, fontFamily: SERIF, fontStyle: "italic" }}>{c.desc}</span>
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
            <div className="mt-6 flex gap-2">
              <Btn onClick={finishCull} primary disabled={kept.length < 5 || kept.length > 10}>Continue to ranking</Btn>
              <Btn onClick={() => setPhase("sort")}>Back</Btn>
            </div>
          </div>
        )}

        {phase === "rank" && (
          <div>
            <div className="mb-4" style={{ color: CREAM, fontFamily: SERIF, fontStyle: "italic" }}>
              Order them. Number one is the value most central to who you are.
            </div>
            <div className="space-y-2">
              {ranking.map((id, i) => {
                const c = cards[id];
                return (
                  <div key={id} className="flex items-center gap-3 rounded-sm px-4 py-3 shadow" style={{ background: PAPER }}>
                    <span style={{ color: ACCENT, fontFamily: MONO, fontWeight: 700, width: 24 }}>{i + 1}</span>
                    <span className="flex-1">
                      <span style={{ color: INK, fontWeight: 800, letterSpacing: "0.06em" }}>{c.name}</span>
                      <span className="block text-sm" style={{ color: INK, fontFamily: SERIF, fontStyle: "italic" }}>{c.desc}</span>
                    </span>
                    <button onClick={() => move(i, -1)} disabled={i === 0} aria-label="Move up"
                      className="px-2 py-1 rounded disabled:opacity-25 focus:outline-none focus-visible:ring-2"
                      style={{ color: INK, fontFamily: MONO }}>&#9650;</button>
                    <button onClick={() => move(i, 1)} disabled={i === ranking.length - 1} aria-label="Move down"
                      className="px-2 py-1 rounded disabled:opacity-25 focus:outline-none focus-visible:ring-2"
                      style={{ color: INK, fontFamily: MONO }}>&#9660;</button>
                  </div>
                );
              })}
            </div>
            <div className="mt-6 flex gap-2">
              <Btn onClick={() => setPhase("export")} primary>Finish</Btn>
              <Btn onClick={() => { setCut([]); setPromo([]); setPhase("cull"); }}>Back</Btn>
            </div>
          </div>
        )}

        {phase === "export" && (
          <div>
            <div className="relative rounded-sm shadow-xl w-full px-6 pb-6" style={{ background: PAPER, transform: "rotate(-0.4deg)",
              backgroundImage: "repeating-linear-gradient(to bottom, transparent 0px, transparent 31px, " + RULE + " 31px, " + RULE + " 32px)" }}>
              <div className="absolute left-0 right-0" style={{ top: 44, borderTop: "2px solid " + REDRULE }} />
              <div className="relative" style={{ paddingTop: 10 }}>
                <div style={{ color: INK, fontWeight: 800, letterSpacing: "0.08em", lineHeight: "32px" }}>MY VALUES</div>
                {ranking.map((id, i) => (
                  <div key={id} style={{ color: INK, fontFamily: SERIF, lineHeight: "32px" }}>
                    <span style={{ fontFamily: MONO, color: ACCENT, fontSize: 13 }}>{i + 1}.</span> {cards[id].name.toLowerCase()}
                  </div>
                ))}
              </div>
            </div>
            <div className="mt-6 mb-2" style={{ color: CREAM, fontFamily: SERIF, fontStyle: "italic" }}>
              Copy this into Bear, your Rhodia, or back into our chat:
            </div>
            <textarea id="vcs-md" readOnly value={md} rows={12}
              className="w-full rounded p-3 text-xs focus:outline-none focus-visible:ring-2"
              style={{ background: "rgba(0,0,0,0.25)", color: CREAM, fontFamily: MONO, border: "1px solid rgba(255,255,255,0.15)" }} />
            <div className="mt-3 flex flex-wrap gap-2">
              <Btn onClick={copy} primary>{copied ? "Copied" : "Copy results"}</Btn>
              <Btn onClick={() => setPhase("rank")}>Back</Btn>
              <Btn onClick={reset} style={{ color: "#E8B4AC" }}>Start over</Btn>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
