---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/particles/bosons/src/G4OpticalPhoton.cc:44-85
  - source/particles/management/include/G4ParticleDefinition.hh:79-80,98-125,273-332
  - source/particles/management/src/G4ParticleDefinition.cc:90-136
  - source/particles/bosons/src/G4Geantino.cc:55-74
  - source/particles/bosons/src/G4PhononLong.cc:57-62
  - source/processes/optical/include/G4OpAbsorption.hh:87-91
  - source/processes/optical/include/G4OpBoundaryProcess.hh:281-284
related: []
---

# g4-src-opticalphoton-sentinel

A typical per-step SD that records a particle-ID branch will store
`track->GetDefinition()->GetPDGEncoding()`. For most particles this is a
standard Monte Carlo particle number: 11 for e−, 2212 for proton, 22 for
gamma. The optical photon returns something unexpected, and the wrong sentinel
assumption in analysis code would cause silent misidentification. The question
of what value to actually expect requires reading the constructor, not trusting
the name "photon".

## What the source actually does

### The constructor: PDG encoding set to −22

`source/particles/bosons/src/G4OpticalPhoton.cc:63-70`:

```cpp
anInstance = new G4ParticleDefinition(
              name,         0.0*MeV,       0.0*MeV,         0.0,
                 2,              -1,            -1,
                 0,               0,             0,
   "opticalphoton",               0,             0,        -22,
              true,            -1.0,          nullptr,
         false,        "photon",               0
             );
```

Reading the argument list against the constructor signature
(`G4ParticleDefinition.hh:79-80`: `...G4int anti_encoding = 0`):
the column labelled "PDG encoding" is the 14th argument, which is **−22**.

The electromagnetic photon (gamma) has PDG encoding **+22**.
`G4OpticalPhoton` uses −22 to distinguish it from gamma at the PDG-encoding
level, even though both particles have spin-1 and zero mass. The encoding −22
does not correspond to any particle in the PDG Review of Particle Physics;
it is a Geant4 internal convention chosen to avoid colliding with gamma (+22)
while retaining a mnemonic relationship.

The anti-encoding argument is the last positional argument (`0`), so
`theAntiPDGEncoding` is set by the base class rule:
`theAntiPDGEncoding = -1 * encoding = -1 * (-22) = +22`
(`G4ParticleDefinition.cc:105`).

### How optical processes identify optical photons

Every optical process uses **pointer comparison against the singleton
`G4OpticalPhoton` instance**, not PDG encoding and not name string comparison.

`source/processes/optical/include/G4OpAbsorption.hh:87-91`:

```cpp
inline G4bool G4OpAbsorption::IsApplicable(
  const G4ParticleDefinition& aParticleType)
{
  return (&aParticleType == G4OpticalPhoton::OpticalPhoton());
}
```

`source/processes/optical/include/G4OpBoundaryProcess.hh:281-284`:

```cpp
inline G4bool G4OpBoundaryProcess::IsApplicable(
  const G4ParticleDefinition& aParticleType)
{
  return (&aParticleType == G4OpticalPhoton::OpticalPhoton());
}
```

`G4OpticalPhoton::OpticalPhoton()` returns the singleton instance pointer
(`G4OpticalPhoton.cc:82-85`). Every optical process compares the address of
the `G4ParticleDefinition` passed at applicability-check time against this
singleton address. PDG code −22 plays no role in runtime process dispatch.

### `GetPDGEncoding()` confirmed from source

`G4ParticleDefinition::GetPDGEncoding()` is a trivial accessor
(`G4ParticleDefinition.hh:123`):

```cpp
G4int GetPDGEncoding() const { return thePDGEncoding; }
```

`thePDGEncoding` is initialised from the constructor's `encoding` argument
(`G4ParticleDefinition.cc:104`: `thePDGEncoding(encoding)`). For
`G4OpticalPhoton`, that argument is −22 as shown above. There is no
post-construction override for optical photons.

So `track->GetDefinition()->GetPDGEncoding()` returns **−22** for an optical
photon track.

### Other Geant4 particles with PDG encoding 0

Several Geant4 internal particles use encoding 0:

- `G4Geantino` (`G4Geantino.cc:66`): encoding argument is `0`.
- `G4ChargedGeantino` (`G4ChargedGeantino.cc:66`): encoding argument is `0`.
- `G4UnknownParticle` (`G4UnknownParticle.cc:65`): encoding argument is `0`.
- `G4ChargedUnknownParticle` (`G4ChargedUnknownParticle.cc:77`): encoding `0`.
- `G4PhononLong`, `G4PhononTransFast`, `G4PhononTransSlow`
  (`G4PhononLong.cc:60`, etc.): encoding `0`.

**`G4OpticalPhoton` does not use 0.** It uses −22. Code that checks
`pdg == 0` to identify optical photons is wrong; it would match geantinos
and phonons instead.

### Why −22 and not 0

The PDG assigns 0 to no real particle (0 is the code for "unknown/unassigned"
in the MCParticle convention). Geant4 chose −22 for optical photons to signal
"related to a photon but not a true gamma" while remaining distinguishable in
`pdg/I` histograms. The relation to −22 (the anti-code of gamma) reflects that
optical photons were historically considered a different representation of the
photon, not an independent particle species.

## Gotchas / edge cases

1. **Filtering on `pdg == 22` silently drops optical photons.** An analysis
   that selects "all photons" by `pdg == 22` will miss every optical photon
   hit. The correct inclusive cut for any photon-like particle is
   `pdg == 22 || pdg == -22`.

2. **Optical photons deposit zero ionising energy in `ProcessHits`.** A
   typical per-step SD already guards with `if (edep <= 0.) return false`.
   Optical photons have zero ionising energy deposit by construction (they
   scatter at surfaces, not through ionisation), so they are silently dropped
   by such a guard regardless of any PDG-code check.
   If scintillation or Cherenkov are added with a dedicated optical SD, the
   filter must be dropped or replaced.

3. **Anti-encoding is +22.** A hypothetical anti-optical-photon (not a real
   Geant4 particle) would have encoding +22 by the default anti-encoding rule.
   This does not collide in practice because gamma (+22) and optical photon
   (+22 anti-encoding) are never confused at the pointer-identity level used
   by optical processes, but a numeric analysis treating +22 as "gamma only"
   would be wrong if optical photon anti-encodings ever appeared.

4. **Phonons and geantinos both have PDG = 0.** In a condensed-matter or
   low-temperature simulation using Geant4's phonon library, `pdg == 0` in
   the TTree would be ambiguous among geantinos, phonons, and unknown
   particles. The `volume/C` branch is the only reliable way to distinguish
   which sensitive volume saw these tracks.

5. **`FillQuarkContents` prints a warning for non-standard encodings.** For
   any particle whose PDG encoding cannot be decomposed into quark content,
   `G4ParticleDefinition.cc:126-135` issues a `JustWarning` exception
   "Strange PDGEncoding". The optical photon triggers this at construction
   time because −22 has no quark decomposition. This is expected and
   informational, not fatal.
