---
layout: default
title: geant4_claude
---

A public Claude Code plugin (MIT). Geant4 + ROOT in a pinned apptainer image; analysis on the host with [`uproot`](https://github.com/scikit-hep/uproot5).

**v0.0.4** · 2026-05-14 · [release notes](https://github.com/zhaozhiwen/geant4_claude/blob/main/CHANGELOG.md)

## Install

In Claude Code:

```text
/plugin marketplace add zhaozhiwen/geant4_claude
/plugin install geant4-claude
```

`/plugin update` handles upgrades. [Apptainer](https://apptainer.org) ≥ 1.4 must already be on the host; the plugin pulls its pinned container image on first use.

## Quickstart

The `geant4` orchestrator skill auto-loads on any "simulate / build / run a Geant4 …" request. Tell Claude what you want:

```text
> Create a Cherenkov simulation: a 1×1×1 m CO2 gas radiator at 1 atm,
  1 GeV e- beam along the central axis, ideal downstream flux backplate
  collects photons, ROOT output, then analyze with a 1-D photon-count
  histogram and a 2-D photon (x, y) distribution.
```

The skill asks any missing-spec questions, shows a brief plan, runs it on approval.

Three independent paths to a working simulation:

- **Describe it** — orchestrator drives `init → detector → build → run → analyze` end-to-end.
- **Try the shipped example** — `/geant4-claude:geant4-example` drops a lead-block demo into your workspace as a one-shot smoke test.
- **Bring your own `main.cc`** — when you need custom physics (optical photons, HP neutrons, polarization), hard-coded geometry, or a non-`Hits` output schema.

Full walkthroughs in the [README](https://github.com/zhaozhiwen/geant4_claude#quickstart).

## What it does

- **NL-driven geometry as a first-class step.** `/geant4-claude:geant4-detector` translates a plain-English detector spec into a validated standalone GDML file. Edit the file or re-describe to iterate — no rebuild required.
- **Single runtime seam.** All Geant4 / ROOT / CMake calls go through `bin/g4run`. The container tag is pinned in one place. The plugin contributes no compiled code — every binary is the user's binary, built inside the container.
- **Schema-aware analysis.** `/geant4-claude:geant4-analyze` inspects the ROOT file and either uses the canned `Hits`-TTree plot or generates a custom analysis script tailored to whatever branches it actually finds.

Architecture, contracts, and the post-v0.0.3 hardening backlog: [DESIGN.md](DESIGN).

## Requirements

- [Apptainer](https://apptainer.org) ≥ 1.4 on Linux.
- Python 3.9+ on the host with `uproot numpy matplotlib` (only for `/geant4-claude:geant4-analyze`; auto-installed into the plugin's managed venv on first analyze).
- ~2.5 GB of disk for the cached container image.
- Claude Code with plugin support.

## Links

- [Source on GitHub](https://github.com/zhaozhiwen/geant4_claude)
- [Architecture (DESIGN.md)](DESIGN)
- [Release notes (CHANGELOG.md)](https://github.com/zhaozhiwen/geant4_claude/blob/main/CHANGELOG.md)
- [License (MIT)](https://github.com/zhaozhiwen/geant4_claude/blob/main/LICENSE)

## Acknowledgments

- **Geant4** — the simulation toolkit this plugin drives. See [geant4.web.cern.ch/about](https://geant4.web.cern.ch/about) and cite the Geant4 Collaboration's references in any publication that uses its output.
- **`g4install` container** — built and maintained at Jefferson Lab; see [jeffersonlab.github.io/g4home](https://jeffersonlab.github.io/g4home).
