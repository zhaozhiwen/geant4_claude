---
type: synthesis
domain: physics
status: stable
related: ["[[em-processes]]", "[[optical-photon-physics]]"]
---

# PDG access — Python client (default), REST API (backup), bulk SQLite

The [Particle Data Group](https://pdg.lbl.gov/) "Review of Particle Physics" is the canonical reference for particle data. This page is **how to fetch from it on demand**. We do *not* mirror PDG content in the wiki — pages that need a value query PDG and cite the specific edition.

**Default path: the Python `pdg` client.** It bundles the SQLite snapshot in the pip wheel, works offline, has no rate limit, and accepts MC IDs / names / PDG identifiers. Use it for everything by default. **Fall back to REST** only when you need a value newer than your installed `pdg` package, when you can't install Python deps, or when you want to confirm a Python result against the live database. All three methods serve the same underlying PDG dataset.

## What you can get vs what you can't

**Via API (REST, Python, SQLite):** particle properties — mass, width, charge, lifetime, branching fractions, Monte Carlo IDs, quantum numbers (J, P, C, …), historical edition values.

**NOT via API:** the **Review of Particle Physics chapter text**. Chapters most relevant to Geant4 — *Passage of Particles Through Matter* (Bethe-Bloch, ionization, multiple scattering), *Atomic and Nuclear Properties of Materials*, *Hadronic Cross-Section Reviews* — live at <https://pdg.lbl.gov/2025/reviews/> as HTML/PDF only. Use `WebFetch` or `curl` for those, not the API.

## Three access methods (in order of preference)

| Method | Endpoint / install | When to use |
|--------|--------------------|-------------|
| **Python client** *(default)* | `pip install pdg` — v0.2.2 ships the 2025 edition with a bundled SQLite snapshot. | **Default for everything.** Offline, no rate limit, ergonomic API; accepts names / MC IDs / PDG identifiers. |
| REST API *(backup)* | `https://pdgapi.lbl.gov/` (JSON) | When you need values newer than the installed `pdg` package, can't install Python deps, or want to verify a Python result against the live DB. **Rate limit: < 2 req/s** (5-min IP block on violation). |
| Bulk SQLite | `pdgall-2025-v0.2.2.sqlite` from <https://pdg.lbl.gov/2025/api/> | Heavy joins across particles, sharing a snapshot, or writing straight SQL. Drop in `wiki/raw/` (gitignored, like `geant4-src/`) when needed. |

## Particle identifiers — three conventions

| Convention | Example | Notes |
|-----------|---------|-------|
| **Monte Carlo ID** | `2212` (proton), `211` (π⁺), `22` (γ), `−22` (`opticalphoton` — Geant4 sentinel, see `G4OpticalPhoton.cc:67`) | Standard PDG numeric IDs; what Geant4 uses internally. |
| **Name string** | `"p"`, `"pi+"`, `"gamma"`, `"H"` | Accepted by the Python client. |
| **PDG Identifier** | `S016M` = "proton mass" (MeV); `S008.1/2025` = "pi+ → μ+ ν_μ branching fraction, 2025 edition" | Alphanumeric, **quantity-centric** — one identifier per *(particle, quantity)* pair, optionally suffixed `/EDITION`. Find them in the JSON button on each pdgLive page. |

The PDG-Identifier model is the gotcha: a single particle has many identifiers (one for mass, one for width, one per branching fraction). The Python client hides this; the REST API doesn't.

## REST endpoint cheat sheet

Base: `https://pdgapi.lbl.gov/`

- `GET /info` — edition, citation string, license, timestamp.
- `GET /summaries/{PDGID}` — current summary-table value for that quantity.
- `GET /summaries/{PDGID}/{EDITION}` — historical (e.g. `/summaries/S126M/2022`).
- `GET /listings/{PDGID}` — measurement-level detail: experimental references, systematics breakdown, footnotes. Separate call from `/summaries`.

## Examples (verified against PDG 2025, `pdg==0.2.2`, May 2026)

### Python (default): proton mass, charge, name

```python
import pdg
api = pdg.connect()                              # opens the bundled SQLite; no network call
proton = api.get_particle_by_mcid(2212)
print(proton.name, proton.mass, proton.charge)   # 'p' 0.93827208816 1.0
```

**Unit gotcha:** the Python client returns mass as a **plain float in GeV** — not a `PdgQuantity` and not in MeV. (Charge and `quantum_J` are also plain numbers / fractions.) Convert if you need MeV.

### Python: name lookup is fine too

```python
api.get_particle_by_name('p').mass               # 0.93827208816
```

### Python: massless particles return `None`

```python
api.get_particle_by_mcid(22).mass                # None  (photon — not 0, not 0.0)
```

Don't blindly `float(p.mass)` — guard for `None` first.

### Python: branching fractions

```python
pip = api.get_particle_by_mcid(211)              # pi+
for bf in pip.exclusive_branching_fractions():
    print(bf)
# Data for PDG Identifier S008.1/2025: pi+ --> mu+ nu_mu
# Data for PDG Identifier S008.2/2025: pi+ --> e+ nu_e
# ... 9 channels total in the 2025 edition
```

The trailing `/2025` is the edition; `S008` is the pi+ slot, `.N` is the channel.

### Python: Geant4 sentinels are not in PDG

```python
api.get_particle_by_mcid(-22)
# ValueError: No particle found with MC ID -22
```

`opticalphoton` (Geant4 PDG = −22) and other Geant4-internal sentinels have no PDG entry — wrap PDG lookups in try/except when iterating over Geant4 particle lists.

### REST (backup): same proton-mass query

Use this when you need to verify a value against the live database, or when Python isn't available.

```bash
curl -s 'https://pdgapi.lbl.gov/summaries/S016M' | jq '.pdg_values[0]'
```

```json
{
  "value": 938.27208816,
  "error_positive": 2.9e-07,
  "error_negative": 2.9e-07,
  "unit": "MeV",
  "comment": "2018 CODATA",
  "type": "OUR EVALUATION"
}
```

REST returns canonical PDG units (MeV); the Python client gives you GeV. Same number, different units. The full response also carries `edition`, `description`, and `request_url` for citation.

## Citation

PDG data has been **CC-BY-4.0** since the 2024 edition. Pages in this wiki that quote a PDG value must include the citation string returned by `GET /info`. Current template:

> S. Navas *et al.* (Particle Data Group), *Phys. Rev. D* **110**, 030001 (2024) and 2025 update.

Always record the **edition year** (e.g. "PDG 2025") next to the cited value — values change between editions.

## When NOT to ingest

Same rule as `raw/geant4-src/` and the deepwiki MCP: **do not bulk-mirror PDG content into wiki pages**. Synthesis pages cite PDG with the citation string + edition; the data lives at PDG, not in the wiki repo. The bulk SQLite goes in `wiki/raw/` (gitignored) only when an active piece of work needs it.

## Gotchas

- PDG identifiers are **quantity-centric**, not particle-centric. One particle ≠ one identifier.
- `/summaries` and `/listings` are separate calls; summary values don't include measurement-level detail and vice versa.
- The REST API is *for incidental access* per PDG's own docs; the Python client / SQLite are the right paths for anything systematic.
- Year-versioned URLs (`/2025/api/`, `/2024/api/`) are the convention; there's no documented `latest` alias — pin the edition explicitly when scripting.
- **Units differ between REST (MeV) and Python (GeV).** Convert before comparing.
- **Massless particles return `mass = None`** in the Python client, not 0. Guard before arithmetic.
- **Geant4 sentinel particles** (`opticalphoton` = −22, etc.) raise `ValueError` from the Python client. Wrap lookups in try/except when iterating over Geant4 particle lists.
