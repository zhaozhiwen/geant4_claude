---
type: concept
domain: physics
g4_version: 11.4.0
status: stable
related: ["[[physics-list-factory]]", "[[optical-photon-physics]]"]
---

# em-processes

The electromagnetic (EM) processes Geant4 simulates determine how
electrons, positrons, muons, and photons lose energy and change
direction in matter. They are the backbone of almost every Geant4
simulation.

## Primary photon processes

| Process | Class | Description |
|---------|-------|-------------|
| Photoelectric effect | `G4PhotoElectricEffect` | Photon absorbed, photoelectron ejected. Dominant below ~0.1 MeV in high-Z. |
| Compton scattering | `G4ComptonScattering` | Photon scatters off electron, loses energy. Dominant 0.1–10 MeV. |
| Pair production | `G4GammaConversion` | Photon converts to e⁺e⁻ in nuclear field. Threshold 1.022 MeV; dominant above 10 MeV. |
| Rayleigh scattering | `G4RayleighScattering` | Elastic scattering off bound electrons. Small correction at low energy. |

## Primary electron/positron processes

| Process | Class | Description |
|---------|-------|-------------|
| Ionisation | `G4eIonisation` | Continuous energy loss along track (Bethe-Bloch); δ-ray production above threshold. |
| Bremsstrahlung | `G4eBremsstrahlung` | Radiative energy loss in nuclear field; photon emission. Dominates above critical energy (~10 MeV in Al). |
| Multiple scattering | `G4eMultipleScattering` | Angular deflection from many small collisions. Urban model by default. |
| Positron annihilation | `G4eplusAnnihilation` | e⁺e⁻ → 2γ (511 keV each) at rest; in-flight annihilation also modelled. |

## EM constructor options

The physics list suffix selects which EM constructor is used:

| Suffix | Constructor | Use case |
|--------|-------------|----------|
| (none / `_EMV`) | `G4EmStandardPhysics` | Default. Balanced accuracy/speed. |
| `_EMX` | `G4EmStandardPhysics_option3` | Higher accuracy, more CPU. Detector studies. |
| `_EMY` | `G4EmStandardPhysics_option4` | Best accuracy (Livermore at low E). Medical dosimetry. |
| `_EMZ` | `G4EmStandardPhysics_option1` | Fastest; good for calorimeter shower shapes. |
| `_PEN` | `G4EmPenelopePhysics` | Penelope condensed-history. Medical. |
| `_LIV` | `G4EmLivermorePhysics` | Livermore data-based EM below 1 GeV. |

## Energy-loss straggling and δ-rays

Geant4 handles continuous energy loss (`dE/dx`) and discrete δ-ray
production above a production threshold (`G4ProductionCuts`). The
threshold is set in range (mm), not energy — Geant4 converts per
material. Tighter cuts → more secondaries → slower simulation.
Typical: 0.1–1 mm range cut for most applications.
