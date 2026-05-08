# wiki/

A compounding knowledge base **for Geant4** — toolkit mechanics, physics that informs it, and source-grounded synthesis. Maintained by Claude across conversations and used by the `geant4_claude` plugin to answer Geant4 and physics questions. The wiki is *not* plugin self-documentation; that lives in [`docs/DESIGN.md`](../docs/DESIGN.md). Based on the [Karpathy LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) pattern.

## Structure

Two source-domain trees plus a top-level cross-domain synthesis dir:

| Directory | What's here |
|-----------|-------------|
| [`sources/geant4-code/`](sources/geant4-code/) | Toolkit mechanics. `examples/` (38 pages, one per canonical Geant4 example) and `synthesis/` (24 pages: concepts, entities, source-grounded synthesis, MVP analysis). |
| [`sources/physics/`](sources/physics/) | Particle physics knowledge, PDG-grounded. Flat. |
| [`synthesis/`](synthesis/) | Cross-domain pages that bridge `physics` and `geant4-code` (e.g. PDG chapter ↔ Geant4 model-class mappings). Flat. |

`raw/` (sibling of `sources/` and `synthesis/`) holds immutable input documents the agent reads but does not modify — see Navigation below. Page type (`concept` / `entity` / `source` / `synthesis`) is in frontmatter, not the directory name.

`em-processes.md` and `optical-photon-physics.md` live in `sources/geant4-code/synthesis/` — they describe what Geant4 *implements*, not pure physics. New PDG-grounded pages go in `sources/physics/`. Bridging pages go in top-level `synthesis/`.

## Navigation

- **[[index|index.md]]** — full page catalog, organized by domain
- **[[log|log.md]]** — history of every ingest and synthesis operation
- **[raw/](raw/)** — input documents (Geant4 source, papers); agent reads, never modifies
- **External:** see [External Geant4 knowledge sources](#external-geant4-knowledge-sources) below — deepwiki, PDG.

## Page frontmatter

```yaml
---
type: concept | entity | source | synthesis
domain: geant4-code
g4_version: 11.4.0
status: stub | draft | stable
related: [other-slug, another-slug]
---
```

## How it grows

**Ingest** — drop a document in `raw/` or paste a URL; ask Claude to ingest it. Claude writes a `sources/` page, updates/creates concept and entity pages, appends to `log.md`, updates `index.md`.

**Query** — ask a question; if the answer is non-trivial, Claude files it as a synthesis page so it persists across sessions.

**Lint** — ask Claude to lint the wiki: finds orphan pages, stale claims, missing cross-links, concepts mentioned in many places but lacking their own page.

## What lives where (quick map)

| Question | Where to look |
|----------|---------------|
| How does the Geant4 step loop work? | `sources/geant4-code/synthesis/g4-src-step-lifecycle.md` |
| When does ProcessHits fire? | `sources/geant4-code/synthesis/g4-src-sd-dispatch.md` |
| Which physics list should I use? | `sources/geant4-code/synthesis/physics-list-factory.md` |
| What EM processes does Geant4 model? | `sources/geant4-code/synthesis/em-processes.md` |
| What changed recently? | `log.md` |
| Example of a full detector app? | `sources/geant4-code/examples/g4-example-advanced-hadrontherapy.md` |
| How do I look up a particle's PDG mass / width / branching fractions? | `sources/physics/pdg-api-access.md` |

## External Geant4 knowledge sources

- **[deepwiki.com/Geant4/geant4](https://deepwiki.com/Geant4/geant4)** — AI-generated docs over the Geant4 repo. Useful as an architectural sitemap; **not** source-verified, so treat answers as hypotheses to verify against `raw/geant4-src/` before citing in a synthesis page. Setup details (the MCP `.mcp.json` shipped by the plugin, tools exposed) are in [`docs/DESIGN.md`](../docs/DESIGN.md).
- **[pdg.lbl.gov/2025/reviews/](https://pdg.lbl.gov/2025/reviews/)** — Review of Particle Physics chapters (PDF). The Geant4-relevant ones are ingested under [`sources/physics/`](sources/physics/) when the chapter is needed.
