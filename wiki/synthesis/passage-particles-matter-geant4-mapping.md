---
type: synthesis
domain: geant4-code
status: stable
related: ["[[passage-particles-matter]]", "[[passage-particles-matter-summary]]", "[[em-processes]]", "[[optical-photon-physics]]", "[[scoring-styles]]"]
---

# PDG Ch. 34 → Geant4 model mapping

Maps each section of [[passage-particles-matter]] (PDG Ch. 34, "Passage of Particles Through Matter") to the Geant4 classes that implement the corresponding physics. This is wiki-specific synthesis — not part of the PDG source — and lives outside `sources/` because it bridges the `physics` and `geant4-code` domains.

The PDG section / equation references point into the full-content rendering; the Geant4 class names are search-anchors for the v11.4 source tree at `wiki/raw/geant4-src/`.

## Mapping

- **Bethe-Bloch (Sec. 34.2.3)** — `G4BetheBlochModel` (relativistic regime), `G4BraggModel` / `G4BraggIonModel` (low-energy proton/ion regime, Sec. 34.2.6).
- **Mean excitation energy $I$ (Sec. 34.2.4)** — `G4IonisParamMat::GetMeanExcitationEnergy()`, populated from NIST tables in `G4NistMaterialBuilder`.
- **Density correction $\delta(\beta\gamma)$ (Sec. 34.2.5)** — `G4DensityEffectData` (Sternheimer parameters), evaluated by `G4IonisParamMat::ComputeDensityEffect()`.
- **δ-ray production (Sec. 34.2.7)** — secondary-electron sampling in `G4MollerBhabhaModel` and the heavy-particle Bragg/Bethe models, gated by the production cut.
- **Restricted energy loss / Fermi plateau (Sec. 34.2.8)** — production cuts in Geant4 implement $W_{\rm cut}$; PAI models (`G4PAIModel`, `G4PAIPhotModel`) when the Landau form is too narrow.
- **Energy-loss fluctuations (Sec. 34.2.9)** — `G4UniversalFluctuation` (default Landau-like), `G4IonFluctuations` for ions; `G4PAIModel`/`G4PAIPhotModel` for thin Si and gas TPCs (Bethe-Fano-class straggling, Figs. 34.7–34.8).
- **Multiple scattering (Sec. 34.3, Lynch & Dahl Eq. 34.16)** — `G4UrbanMscModel` (default for $e^\pm$, hadrons), `G4WentzelVIModel` (high-energy hadrons/muons), `G4GoudsmitSaundersonMscModel` (precision $e^\pm$).
- **Radiation length $X_0$ (Sec. 34.4.2, Tsai Eq. 34.25)** — computed at material build time, accessor `G4Material::GetRadlen()`.
- **$e^\pm$ stopping power, Møller/Bhabha (Sec. 34.4.1)** — `G4MollerBhabhaModel` for ionization above the production cut.
- **Bremsstrahlung (Sec. 34.4.3)** — `G4SeltzerBergerModel` (sub-1 GeV, NIST tables), `G4eBremsstrahlungRelModel` (high-energy with LPM, Sec. 34.4.6); orchestrated by `G4eBremsstrahlung`.
- **Critical energy $E_c$ (Sec. 34.4.4)** — not stored as a material property; emerges from the balance of `G4eIonisation` and `G4eBremsstrahlung` cross sections.
- **Photon photoelectric / Compton / Rayleigh / pair (Sec. 34.4.5)** — `G4PEEffectFluoModel`, `G4KleinNishinaCompton` (or Livermore/Penelope variants), `G4LivermoreRayleighModel`, `G4PairProductionRelModel`/`G4BetheHeitlerModel`.
- **LPM (Sec. 34.4.6)** — built into `G4eBremsstrahlungRelModel` and `G4PairProductionRelModel` via the `LPMEnergy()` / `LPMfunctions()` machinery.
- **Photonuclear / electronuclear (Sec. 34.4.7)** — `G4PhotoNuclearProcess` (with `G4HadronInelasticProcess` cross sections), `G4ElectroNuclearProcess`/`G4ElectroVDNuclearModel`.
- **EM cascade longitudinal/transverse profile (Sec. 34.5)** — emerges from the model chain above; parametric fast simulation via `GFlash` (`G4GFlashShowerModel`) uses Eqs. (34.35)–(34.38).
- **Muon ionization + radiative losses (Sec. 34.6, Eq. 34.39)** — `G4MuIonisation` ($a(E)$), `G4MuPairProduction` + `G4MuPairProductionModel`, `G4MuBremsstrahlung` + `G4MuBremsstrahlungModel`, `G4MuonNuclearInteraction` with `G4MuonVDNuclearModel` ($b(E)\,E$ pieces).
- **Cherenkov (Sec. 34.7.1, Eqs. 34.43–34.44)** — `G4Cerenkov` process, with the material's `G4MaterialPropertiesTable` carrying $n(\lambda)$. See [[optical-photon-physics]].
- **Transition radiation (Sec. 34.7.3)** — `G4TransitionRadiation` and the family of `G4VXTRenergyLoss` subclasses (regular foil stacks, irregular, gamma); the energy spectrum follows Eq. (34.47).
