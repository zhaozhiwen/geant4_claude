---
type: synthesis
domain: physics
status: stable
source: PDG 2025 Review of Particle Physics, Chapter 34 "Passage of Particles Through Matter"
source_url: https://pdg.lbl.gov/2025/reviews/rpp2025-rev-passage-particles-matter.pdf
license: CC-BY-4.0
citation: S. Navas et al. (Particle Data Group), Phys. Rev. D 110, 030001 (2024) and 2025 update.
related: ["[[passage-particles-matter]]", "[[passage-particles-matter-geant4-mapping]]", "[[pdg-api-access]]", "[[em-processes]]", "[[optical-photon-physics]]"]
---

# Passage of Particles Through Matter (PDG Ch. 34) — wiki summary

PDG Chapter 34, revised August 2023 by **D.E. Groom** (LBNL) and **S.R. Klein** (NSD LBNL; UC Berkeley), is the canonical reference for the EM and EM-adjacent interactions that drive every Geant4 detector simulation. This page is a one-screen orientation. For depth, follow the pointers below.

## Where to read what

| You want… | Go to |
|---|---|
| The full chapter — all prose, equations, figures, references | [[passage-particles-matter]] (verbatim, 807 lines) |
| The original paper, citable, with publisher typesetting | [PDG 2025 PDF](https://pdg.lbl.gov/2025/reviews/rpp2025-rev-passage-particles-matter.pdf) |
| Map from PDG sections to Geant4 model classes | [[passage-particles-matter-geant4-mapping]] |
| Per-material values (mean excitation $I$, Sternheimer params, $X_0$, $E_c$) | <https://pdg.lbl.gov/2025/AtomicNuclearProperties/> |

## What's in the chapter

Each section in one line so you know which to open:

- **34.1 Notation** — symbols and constants. Includes $K = 0.307\,075$ MeV mol$^{-1}$ cm$^2$, $E_s = 21.2052$ MeV, plasma-energy coefficient $28.816$ eV.
- **34.2 Electronic energy loss by heavy particles** — Bethe formula, mean excitation $I$, density correction, energy-loss fluctuations (Landau / Vavilov / PAI), $\delta$-rays.
- **34.3 Multiple scattering through small angles** — Lynch–Dahl Highland formula, $13.6$ MeV scaling.
- **34.4 Photon and electron interactions in matter** — radiation length ($716.408$ g cm$^{-2}$ Tsai constant), bremsstrahlung, pair production, critical energy ($610/(Z+1.24)$ in solids/liquids, $710/(Z+0.92)$ in gases), photon photoelectric/Compton/Rayleigh, LPM ($7.7$ TeV/cm in lead), photonuclear.
- **34.5 Electromagnetic cascades** — gamma-distribution longitudinal profile, Molière radius, transverse profile.
- **34.6 Muon energy loss at high energy** — $\langle dE/dx\rangle = a(E) + b(E)\,E$; muon critical energy from $a/b$ balance; positron critical-energy fits $5700/(Z+1.47)^{0.838}$ and $7980/(Z+2.03)^{0.879}$.
- **34.7 Cherenkov and transition radiation** — Frank–Tamm yield, Askar'yan radio-Cherenkov, transition-radiation X-ray spectrum ($N_\gamma = 0.59\%\times z^2$ above threshold).

## Why it matters for Geant4 users

When a Geant4 result looks wrong (wrong dE/dx, wrong shower depth, wrong scattering tail), this chapter tells you what the right physics *should* look like. The Geant4 model classes that implement each section are catalogued in [[passage-particles-matter-geant4-mapping]] — open both pages side by side when debugging an EM physics simulation.
