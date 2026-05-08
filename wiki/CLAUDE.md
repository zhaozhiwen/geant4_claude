# CLAUDE.md — `wiki/`

Rules for maintaining this wiki. Schema details are in `README.md`; this file is what you act on.

## Two source domains + a cross-domain synthesis dir

All synthesized knowledge pages live under either `sources/` (organized by domain) or `synthesis/` (cross-domain). `sources/` and `synthesis/` are wiki-internal; **neither is the same as `raw/`** which holds immutable input documents.

| Directory | `domain:` tag | Covers |
|-----------|--------------|--------|
| `sources/geant4-code/` | `geant4-code` | Toolkit mechanics. Two subdirs: `examples/` (one page per Geant4 example, 38 pages) and `synthesis/` (concepts, entities, source-grounded synthesis, MVP analysis, 24 pages). |
| `sources/physics/` | `physics` | Particle physics knowledge, PDG-grounded. Flat. |
| `synthesis/` | `geant4-code` *(usually)* | Cross-domain synthesis pages — content that bridges `sources/physics/` and `sources/geant4-code/`. Use this when a page maps physics concepts to Geant4 implementation, or otherwise belongs to neither single domain alone. Flat. |

`type:` in frontmatter distinguishes `concept` / `entity` / `source` / `synthesis`. Pages in `synthesis/` should be `type: synthesis`.

`em-processes.md` and `optical-photon-physics.md` remain in `sources/geant4-code/synthesis/` — they describe Geant4's implementation of physics. New PDG-grounded pages go in `sources/physics/`. New pages that bridge both — e.g., a PDG chapter mapped to Geant4 model classes — go in top-level `synthesis/`; cross-link, don't duplicate.

## Other directories

| Path | Contents | Who writes |
|------|----------|------------|
| `raw/` | Immutable input documents (PDFs, HTMLs, source trees). Read-only for agent. | Human drops. |
| `index.md` | Flat catalog of every page, organized by domain. | Agent updates on every ingest. |
| `log.md` | Append-only timeline. Never edit past entries. | Agent appends. |
| `README.md` | Human-facing overview. | Human edits when schema changes. |
| `CLAUDE.md` | This file. | Human edits when rules change. |

## Naming

- Kebab-case, lowercase. One concept per file.
- Don't embed the directory in the filename: `sources/geant4-code/synthesis/scoring-mesh.md`, not `sources/geant4-code/synthesis/concept-scoring-mesh.md`.
- Page type is in frontmatter (`type: concept | entity | source | synthesis`), not in the filename.

## Required on every ingest

1. Geant4 examples → `sources/geant4-code/examples/`; concepts, entities, source-synthesis → `sources/geant4-code/synthesis/`; PDG-grounded particle/process physics → `sources/physics/`; pages that bridge both domains (PDG ↔ Geant4 mapping) → top-level `synthesis/`.
2. Include `type:` and `domain:` in frontmatter (`domain: geant4-code` or `domain: physics`).
3. Append one entry to `log.md`.
4. Update `index.md` under the correct section (alphabetical within section).

## Required on every non-trivial query answer

File the answer as `sources/geant4-code/synthesis/<slug>.md` (toolkit mechanics) or `sources/physics/<slug>.md` (PDG-grounded). Append to `log.md`. Update `index.md`.

## Cross-linking (Obsidian wikilinks)

The wiki is set up as an Obsidian vault rooted at `wiki/`. Internal links use Obsidian's `[[wikilink]]` syntax — **no paths, no `.md` extension** — because Obsidian resolves by filename across the entire vault. Slugs are unique by design (one concept per file), so this works.

| Target | Form |
|---|---|
| Any wiki page (same dir, other dir, other domain) | `[[scoring-styles]]` or `[[scoring-styles\|custom display text]]` |
| Section anchor inside a wiki page | `[[scoring-styles#Decision guide]]` |
| Frontmatter `related:` (renders as Obsidian property links) | `related: ["[[init-quartet]]", "[[scoring-styles]]"]` |
| **Outside the vault** — `docs/DESIGN.md`, `wiki/raw/geant4-src/`, external URLs | Standard markdown: `[text](../docs/DESIGN.md)`, `[geant4 source](../../../raw/geant4-src/)`, `[Geant4 site](https://geant4.web.cern.ch/)` |

Every page must have at least one inbound link from `index.md` or another page. Orphans are a lint error.

## What NOT to do

- Do not modify files in `raw/`.
- Do not duplicate `docs/DESIGN.md`, skills, or command content — link instead.
- Do not write tutorials. Those belong in skills.
- Do not write stubs with no body.
- Do not edit past entries in `log.md`.
- Do not ingest deepwiki content as wiki pages. If `mcp__deepwiki__ask_question` / `read_wiki_structure` / `read_wiki_contents` are available, use them as orientation only — every claim must be verified against `raw/geant4-src/` before it lands in a synthesis page, and synthesis pages cite the `.cc` file, never deepwiki.

## Relation to other repo files

- `docs/DESIGN.md` (top-level repo) is authoritative for plugin architecture and MVP boundary. The wiki must not duplicate it; cross-link only when needed.
- Top-level `CLAUDE.md` governs the plugin; this file governs the wiki only.
