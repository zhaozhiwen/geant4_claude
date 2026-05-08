# Wiki log

Append-only chronological record. One entry per ingest, query that
produced a synthesis page, or lint pass. Each entry starts with a
parseable prefix so simple unix tools work:

```bash
grep "^## \[" wiki/log.md | tail -10
```

Entry format:

```
## [YYYY-MM-DD] <op> | <subject>
<one to three lines on what was done and which pages were touched>
```

`<op>` is one of: `ingest`, `query`, `synthesis`, `lint`, `meta`.

---

## [2026-05-07] lint | added 3 missing cross-links between concept and source-grounded counterparts
Lint pass found three under-linked non-example pages (only inbound from
`index.md`). Added cross-links in both directions:
- `[[g4-mt-run-manager]]` (entity) ← linked from `g4-src-run-lifecycle-mt`
  (intro paragraph) and `user-actions` (MT-safety section, where
  `G4MTRunManager` is mentioned).
- `[[g4-src-opticalphoton-sentinel]]` (source) ← linked from
  `optical-photon-physics` (new "Optical photon PDG sentinel" subsection at
  the bottom, briefly stating PDG = −22 and pointing to the source-grounded
  page for the derivation).
- `[[magnetic-field-setup]]` (concept) ← linked from `g4-src-field-integration`
  (intro paragraph: "for the user-facing configuration pattern see ...").
Frontmatter `related:` arrays updated on all four edited pages so the link
appears as an Obsidian property too. False-positive "broken links" reported
by the lint script are documentation examples inside inline code spans in
`log.md` and `wiki/CLAUDE.md` (the files explaining the wikilink syntax) —
not real errors.

## [2026-05-07] meta | wiki converted to Obsidian wikilink format
Converted all internal wiki links from `[text](path/file.md)` to Obsidian
`[[wikilink]]` (or `[[wikilink|display]]`) format. Frontmatter `related:`
arrays converted from bare slugs to `["[[slug]]", ...]` so Obsidian renders
them as clickable property links. 174 wikilinks across 22 files now;
outside-vault refs (`docs/DESIGN.md`, `wiki/raw/`, external URLs) deliberately
left as standard markdown so they don't break when Obsidian tries to resolve
them inside the vault. Updated `wiki/CLAUDE.md` Cross-linking section to
document the convention: Obsidian vault rooted at `wiki/`, slugs are unique
so no paths needed in `[[...]]`. Conversion done via a one-shot Python script
(`/tmp/wikify.py`, not committed). Vault is usable as-is in Obsidian: open
`wiki/` as a vault and the graph view + backlinks panel work immediately.

## [2026-05-06] meta | wiki repurposed: pure Geant4/physics knowledge, no plugin self-doc
Full purge of plugin-self-documentation from the wiki. The wiki is now a
Geant4-and-physics knowledge base used by `geant4_claude`, not about it.
Concretely:
- Moved top-level `DESIGN.md` to `docs/DESIGN.md`.
- Deleted `sources/geant4-code/synthesis/mvp-boundary.md`; appended its content
  to `docs/DESIGN.md` as a new "MVP boundary" section.
- Stripped trailing `## Relevant for geant4_claude?` sections from all 38
  example pages and from 9 synthesis pages; stripped `## Implications for
  geant4_claude` from 8 `g4-src-*` pages. Pattern was uniform; sed handled it.
- Surgically rewrote `sensitive-detectors-via-gdml-aux.md` as a
  Geant4-G04-pattern reference (no plugin-specific GenericSD / auxtype
  vocabulary / Hits TTree). Plugin-side details moved to a new
  `docs/DESIGN.md` section "Generic SD via GDML auxiliary tags".
- Stripped the "Where the plugin's bundled `pdg` lives" subsection from
  `pdg-api-access.md`; moved to `docs/DESIGN.md` as "Python deps via
  SessionStart hook".
- Moved the deepwiki MCP install/usage tables from `wiki/README.md` to
  `docs/DESIGN.md`. Wiki now has a one-paragraph external-sources pointer.
- Reframed `wiki/README.md` opening line: "knowledge base for Geant4, used
  by the plugin" instead of "for Geant4 and the plugin".
- Updated 3 inbound `DESIGN.md` references (top-level CLAUDE.md, README.md,
  wiki/CLAUDE.md) to `docs/DESIGN.md`.
Verification: `grep -rE 'geant4_claude|GenericSD|geant4_claude_main|src/geant4'`
across `wiki/sources/`, `wiki/synthesis/` returns zero hits. Mentions of "plugin"
remain only in two cross-link rules in `wiki/CLAUDE.md` (pointers to
`docs/DESIGN.md`) and the external-sources section preamble.

## [2026-05-06] meta | rewrote passage-particles-matter-summary as orientation page
After moving the Geant4 mapping out, the summary's 500-line section-by-section
paraphrase was redundant with the verbatim full-content sibling. Rewrote as a
~40-line orientation/navigation page: 1-paragraph overview, "Where to read what"
table (full content / PDG PDF / Geant4 mapping / per-material AtomicNuclearProperties),
one-line-per-section index of the chapter, and a brief "why it matters for
geant4_claude users" pointer. Detailed prose now lives only in
`passage-particles-matter.md`; the summary's job is fast routing to whichever
of the three siblings (full content, paper PDF, mapping) the reader needs.

## [2026-05-06] meta | added top-level wiki/synthesis/ for cross-domain pages
Moved the 18-bullet "Geant4 cross-references" mapping out of
`sources/physics/passage-particles-matter-summary.md` into a dedicated page
at `synthesis/passage-particles-matter-geant4-mapping.md` (new top-level dir).
Replaced the section in the summary with a one-line pointer; updated its
preamble to drop the "ends with a concrete map" claim and re-target the
mapping reference. Updated `index.md` (new `## synthesis/` section above
`## sources/physics/`), `CLAUDE.md` (new directory row + ingest rule), and
`README.md` (Structure table now 3 rows). Rationale: Geant4-model mappings
of PDG chapters bridge the physics and geant4-code domains and don't fit
under either single-domain `sources/` subtree; flat `synthesis/` is the
right home as we ingest more PDG chapters.

## [2026-05-06] ingest | PDG Ch. 34 split into full-content + summary (chunked rebuild)
First single-shot agent retry for verbatim full-content rendering timed out
at ~80 min without writing. Rebuilt via 10 parallel section-scoped subagents
(one per 34.1, 34.2.1–34.2.5, 34.2.6–34.2.11, 34.3, 34.4.1–34.4.4,
34.4.5–34.4.7, 34.5, 34.6, 34.7, references), each handling 35–385 .txt
lines and 1–7 PDF pages. All 10 completed in 1–3 min each. Stitched into
`sources/physics/passage-particles-matter.md` (807 lines, 27 figures, 90
refs, all 8 spot-check constants verified). Renamed previous 525-line
synthesized version to `sources/physics/passage-particles-matter-summary.md`
(type:source → type:synthesis). The chunked approach turned out to be the
right shape — single-shot agents kept slipping into "high-fidelity summary"
framing despite the brief; per-section agents stayed scoped.
`wiki/index.md` updated with both entries; `passage-particles-matter-summary.md`
preamble already points to the full-content sibling.

## [2026-05-06] ingest | PDG Ch. 34 "Passage of Particles Through Matter" (2025 update)
Added `sources/physics/passage-particles-matter.md` — full-content rendering of
the Groom & Klein PDG review chapter (Sec. 34.1–34.7), preserving PDG equation
numbering (34.1)–(34.47), notation table, Tsai radiation-length formula, Lynch
& Dahl multiple-scattering, LPM/Sternheimer/Bethe-Fano details, and an EM
cascade gamma-distribution profile. All 27 figures covered as prose-only
descriptions with verbatim original captions (no image extraction). Closes
with a Geant4 cross-reference section mapping each chapter section to the
relevant `G4*Model` / `G4*Process` classes (`G4BetheBlochModel`,
`G4UniversalFluctuation`, `G4UrbanMscModel`, `G4eBremsstrahlungRelModel`,
`G4PairProductionRelModel`, `G4Cerenkov`, `G4TransitionRadiation`, etc.).
Source PDF and pdftotext output remain in `wiki/raw/pdg-reviews/`.
`index.md` updated.

## [2026-05-06] meta | pdg auto-installed via SessionStart hook
Added plugin-side machinery so `pdg` (Python particle-data client) installs
automatically when the plugin is enabled, matching deepwiki MCP's existing
auto-install via `.mcp.json`. Three new files at the plugin root:
`requirements.txt` (`pdg>=0.2.2`), `hooks/hooks.json` (SessionStart wiring),
and `hooks/install-deps.sh` (idempotent diff/install with uv-first /
python3-m-venv-fallback into `${CLAUDE_PLUGIN_DATA}/venv/`). Pattern follows
the official Claude Code plugins-reference example for npm `node_modules`
installation. End-to-end tested: first run installs in ~5s, second run is a
3ms silent no-op, modifying `requirements.txt` correctly triggers reinstall.
Updated `wiki/sources/physics/pdg-api-access.md` with a "Where the plugin's
bundled `pdg` lives" subsection — skills/commands invoke
`${CLAUDE_PLUGIN_DATA}/venv/bin/python` directly. Updated top-level
`CLAUDE.md` Repository-conventions table to list `requirements.txt` and
`hooks/`. Plugin install now seeds two external dependencies for the user:
deepwiki MCP (via `.mcp.json`, MCP layer) and `pdg` (via `SessionStart`,
Python layer).

## [2026-05-06] meta | deleted docs/g4_study/ and cleaned wiki references
Removed `docs/g4_study/` (308K, 39 markdown files — the 38 long-form Geant4
example notes plus a README). User-authorized destructive delete. The 38
synthesized example pages in `sources/geant4-code/examples/` retain all their
substantive content; only the leading `Full note: [...]` link to the deleted
notes was stripped (sed across all 38 files). Five synthesis pages had
scattered `docs/g4_study/...` references — replaced with intra-wiki links to
the corresponding `examples/` pages where applicable, deleted otherwise:
`mvp-boundary.md` (3), `sensitive-detectors-via-gdml-aux.md` (1),
`scoring-mesh.md` (1), `init-quartet.md` (1), `physics-list-factory.md` (2).
Cleaned `wiki/index.md` (removed full-notes pointer), `wiki/CLAUDE.md`
(removed cross-link table row + relation note), and top-level `README.md`
(directory-tree line). Past entries in `wiki/log.md` left untouched
(historical record). Net result: wiki self-contained, no external dead links.

## [2026-05-06] meta | moved geant4-code/ and physics/ under sources/
Restructure: `sources/` is now the parent of both domain dirs — pages live at
`wiki/sources/geant4-code/{examples,synthesis}/` and `wiki/sources/physics/`.
Depth shifted by 1, so `../../docs/` → `../../../docs/` (physics) and
`../../../docs/` → `../../../../docs/` (geant4-code) via sed across 42 link
hits. Removed orphan `.gitkeep`s in `entities/`, `synthesis/`, `sources/` left
over from the original Karpathy-pattern setup. Updated `index.md` (63 path
prefixes), `README.md` (Structure + quick-map), `CLAUDE.md` (directory table,
new sources-vs-raw clarifier, depth-aware cross-linking table), and
`docs/g4_study/README.md` (mvp-boundary pointer + alternate-path note). Note:
`sources/` here means "synthesized knowledge sources," distinct from `raw/`
which holds immutable input documents — flagged in `CLAUDE.md`.

## [2026-05-06] meta | reframed pdg-api-access.md: Python default, REST backup
Title and methods table reordered to make the Python `pdg` client the default
path (bundled SQLite, offline, no rate limit) and REST the backup (live values,
no Python deps, verification). Examples reordered Python-first, with REST shown
as the "verify-against-live-DB" path. Added an explicit one-paragraph
default/backup statement at the top noting all three methods serve the same
underlying corpus.

## [2026-05-06] query | tested PDG Python API and corrected pdg-api-access.md
Installed `pdg==0.2.2` in a temp venv (uv, Python 3.11) and ran live queries
against the bundled 2025 SQLite. Three doc bugs found and fixed in
`physics/pdg-api-access.md`:
(1) Proton mass identifier was wrong — `S016M`, not `S126M` (verified via
REST `description: "p MASS (MeV)"`).
(2) Python client returns mass as **plain float in GeV**, not `PdgQuantity` in
MeV — REST stays in MeV; conversion needed when comparing.
(3) Massless particles return `None`, not 0 (photon: `mass = None`); Geant4
sentinels like opticalphoton (mcid = −22) raise `ValueError` from the Python
client. Both gotchas added to the Examples and Gotchas sections, with a
verified pi+ → 9 branching fractions example showing the `S008.N/2025`
identifier shape.
Added `physics/` as a top-level domain alongside `geant4-code/`. One page so far:
`physics/pdg-api-access.md` — how to use the PDG REST API, `pdg` Python client,
and bulk SQLite (no content ingested yet, on-demand reference only). Documented
the API/Review-chapter split (API serves particle data; Bethe-Bloch and process
reviews are PDF/HTML only). Updated `index.md`, `README.md`, `CLAUDE.md` to
reflect the two-domain structure. `em-processes.md` and `optical-photon-physics.md`
remain in `geant4-code/synthesis/` — they describe Geant4's implementation.

## [2026-05-06] meta | added deepwiki as external navigation aid
Added one-line pointer to deepwiki.com/Geant4/geant4 in README.md Navigation
section. Flagged "do not ingest — AI-generated, not source-verified" in
both README.md and CLAUDE.md. Wiki content rules unchanged.

## [2026-05-06] meta | clarified .mcp.json behavior on plugin install
Verified against the official plugins reference: `.mcp.json` at the plugin
root IS the canonical mechanism for plugin-shipped MCP servers — they auto-load
when the plugin is enabled. So our deepwiki entry will work for marketplace
users out of the box, not just for maintainers running `claude mcp add`. Updated
`wiki/README.md` "External: deepwiki MCP" with a three-row "How it gets enabled"
table covering plugin users / repo maintainers / standalone users. Added
`.mcp.json` to the **Repository conventions** table in the top-level `CLAUDE.md`
so a stranger cloning the repo understands what the file is for.

## [2026-05-06] meta | installed deepwiki MCP and documented usage
Registered deepwiki MCP at project scope (`.mcp.json` → `https://mcp.deepwiki.com/mcp`,
no auth) via `claude mcp add`. Server reachable; `tools/list` returns
`read_wiki_structure`, `read_wiki_contents`, `ask_question`. Sanity test:
`ask_question` on opticalphoton PDG returned −22 (correct, matches
`G4OpticalPhoton.cc:67`) but did not cite file:line even when asked — confirms
"hypothesis-to-verify, never citation" framing.
Expanded README.md Navigation pointer into a full **External: deepwiki MCP**
section (install command, tool table, good-vs-bad use). Sharpened CLAUDE.md
rule to name the three `mcp__deepwiki__*` tools and the `raw/geant4-src/`
verification step. Tools become callable in the next session.

## [2026-05-05] meta | wiki collapsed to geant4-code/examples + geant4-code/synthesis
Removed `physics/` and `detector-sim/` top-level dirs. All 38 `g4-example-*.md` pages moved to
`geant4-code/examples/`; 24 non-example pages (concepts, entities, g4-src-*, mvp-boundary,
em-processes, optical-photon-physics) moved to `geant4-code/synthesis/`. Fixed link depths
(`../../docs/` → `../../../docs/`). Updated `index.md`, `CLAUDE.md`, `README.md`, `log.md`,
and `docs/g4_study/README.md` synthesis pointer.

## [2026-05-05] meta | wiki restructured to domain subdirectories
Moved all pages from `concepts/`, `entities/`, `sources/`, `synthesis/` into flat domain
directories: `geant4-code/` (47 pages), `physics/` (9 pages), `detector-sim/` (6 pages).
Updated all intra-wiki relative links. Rewrote `README.md` (compact, human-readable).
Updated `CLAUDE.md` directory table. Updated `index.md` with new paths.

## [2026-05-05] ingest | Geant4 v11.4.0 source code ingested (8 synthesis pages)
Shallow-cloned `github.com/Geant4/geant4` at `v11.4.0` to `wiki/raw/geant4-src/` (gitignored).
Read source for 8 hard questions about toolkit mechanics (not header-level facts):
`g4-src-step-lifecycle`, `g4-src-sd-dispatch`, `g4-src-process-registration-ordering`,
`g4-src-track-and-secondary-lifecycle`, `g4-src-run-lifecycle-mt`,
`g4-src-gdml-auxiliary-walk`, `g4-src-field-integration`, `g4-src-opticalphoton-sentinel`.
Created 5 entity pages: `g4-stepping-manager`, `g4-process-manager`, `g4-mt-run-manager`,
`g4-tracking-manager`, `g4-step`.
Key correction: optical photon PDG = −22 (not 0) — fixed in `optical-photon-physics.md`,
`mvp-boundary.md`, `sensitive-detectors-via-gdml-aux.md`.
Updated concepts: `sensitive-detectors-via-gdml-aux`, `user-actions`, `magnetic-field-setup`,
`scoring-styles` with source-grounded implementation details.

## [2026-05-04] ingest | 38 Geant4 example notes ingested from docs/g4_study/
Created 38 `wiki/sources/` pages (one per example note in docs/g4_study/basic/,
extended/, advanced/). Also created 7 new concept pages from cross-cutting patterns:
`scoring-styles`, `user-actions`, `analysis-manager`, `scoring-mesh`,
`magnetic-field-setup` (geant4-code domain); `em-processes`, `optical-photon-physics`
(physics domain). `index.md` reorganized by domain: 38 sources + 10 concepts + 1 synthesis.

## [2026-05-04] meta | three-domain schema added
Formalized three knowledge domains: `geant4-code`, `physics`, `detector-sim`.
`domain:` frontmatter field added as required. `README.md`, `CLAUDE.md`, and `index.md`
updated; `index.md` reorganized by domain. Existing four pages backfilled with `domain: geant4-code`.

## [2026-05-04] synthesis | three pages added from 38-example study
Added `concepts/physics-list-factory.md`, `concepts/sensitive-detectors-via-gdml-aux.md`,
and `synthesis/mvp-boundary.md`. These resolve the broken `related:` links in
`init-quartet.md` and promote the cross-cutting takeaways to first-class wiki pages.
`index.md` updated; `docs/g4_study/README.md` §Synthesis pointer updated to `synthesis/mvp-boundary.md`.

## [2026-05-04] meta | wiki initialized
Skeleton created per the LLM-Wiki pattern (Karpathy gist). Subdirs:
`raw/`, `concepts/`, `entities/`, `sources/`, `synthesis/`. Schema in
`README.md`, catalog in `index.md`. One seed concept page:
`concepts/init-quartet.md` (highest-leverage idea distilled from the
38-example study corpus in `docs/g4_study/`). Cross-cutting takeaways
left in `docs/g4_study/README.md` rather than copied here; will migrate
to `synthesis/` when one of them needs to grow.
