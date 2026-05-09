---
name: geant4-geometry
description: GDML reference — units, NIST materials, basic solids, placement, and the optional `auxiliary sensitive` tag convention used by the example main. Load when writing or editing geometries/*.gdml.
---

# geant4-geometry

GDML is XML that Geant4 parses at run time via `G4GDMLParser::Read`. Any
Geant4 application can load a GDML file; the file contract here is
generic. The **example main** shipped by `/geant4-example` additionally
auto-attaches a sensitive detector to every logical volume that carries
an `auxiliary` tag of type `sensitive`. User-written mains can adopt the
same convention (the tag is harmless to mains that ignore it) or wire
their own SDs in C++.

## Skeleton

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gdml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:noNamespaceSchemaLocation="http://service-spi.web.cern.ch/service-spi/app/releases/GDML/schema/gdml.xsd">

  <define> … </define>        <!-- optional: constants & rotations -->
  <materials> … </materials>  <!-- optional: only for non-NIST materials -->
  <solids> … </solids>
  <structure> … </structure>
  <setup name="Default" version="1.0">
    <world ref="world_lv"/>
  </setup>
</gdml>
```

`<define>` and `<materials>` are skippable if you only use constants
inline and NIST materials.

## Units

GDML uses *attribute-level* units, not a global unit. Default linear
unit if you forget is **mm**; default angular unit is **rad**.

```xml
<box   lunit="mm" x="10" y="10" z="100"/>
<tubs  lunit="cm" rmin="0" rmax="2" z="20" startphi="0" deltaphi="360" aunit="deg"/>
<position name="p1" unit="mm" x="0" y="0" z="50"/>
<rotation name="r1" unit="deg" x="0" y="90" z="0"/>
```

Always set `lunit` on solids and `unit` on positions/rotations. Don't
mix bare numbers with implicit units.

## Materials (NIST, via reference)

Geant4's NIST manager auto-creates materials when GDML references them.
Common names:

| Use | NIST name |
|-----|-----------|
| Air | `G4_AIR` |
| Vacuum | `G4_Galactic` |
| Lead | `G4_Pb` |
| Iron | `G4_Fe` |
| Copper | `G4_Cu` |
| Tungsten | `G4_W` |
| Water | `G4_WATER` |
| Liquid argon | `G4_lAr` |
| Polyethylene | `G4_POLYETHYLENE` |
| Plastic scintillator | `G4_PLASTIC_SC_VINYLTOLUENE` |
| Silicon | `G4_Si` |
| Germanium | `G4_Ge` |
| LaBr3 | `G4_LANTHANUM_BROMIDE` |

Reference inside a `<volume>`:
```xml
<materialref ref="G4_Pb"/>
```

For a custom material, declare in `<materials>` with `<material>` and
`<fraction>` elements. Prefer NIST when possible — fewer ways to be wrong.

## Solids (most common)

```xml
<box  name="b1"  lunit="mm" x="100" y="100" z="100"/>
<tubs name="t1"  lunit="mm" aunit="deg"
      rmin="0" rmax="50" z="200" startphi="0" deltaphi="360"/>
<sphere name="s1" lunit="mm" aunit="deg"
        rmin="0" rmax="50" startphi="0" deltaphi="360"
        starttheta="0" deltatheta="180"/>
<cone name="c1" lunit="mm" aunit="deg"
      rmin1="0" rmax1="20" rmin2="0" rmax2="50" z="100"
      startphi="0" deltaphi="360"/>
```

Booleans: `<union>`, `<subtraction>`, `<intersection>` reference two
solids and an optional position/rotation.

## Logical volumes & placement

```xml
<structure>
  <volume name="det_lv">
    <materialref ref="G4_Pb"/>
    <solidref    ref="b1"/>
    <auxiliary auxtype="sensitive" auxvalue="true"/>   <!-- score this volume -->
  </volume>

  <volume name="world_lv">
    <materialref ref="G4_AIR"/>
    <solidref    ref="world_solid"/>
    <physvol>
      <volumeref ref="det_lv"/>
      <position name="p_det" unit="mm" x="0" y="0" z="0"/>
      <!-- optional: <rotationref ref="r1"/> or inline <rotation .../> -->
    </physvol>
  </volume>
</structure>
```

Naming convention used elsewhere in the plugin:
- solid names end in `_solid`,
- logical volumes end in `_lv`,
- physical-volume names need not be unique but should be descriptive.

The world volume must be the last one declared (or simply be the one
referenced by `<setup>/<world>`). It should be large enough to enclose
all daughters with a comfortable margin (10–20% of the largest daughter
dimension, typically).

## The "sensitive" auxiliary tag (example main convention)

The example main looks for this exact pattern:

```xml
<auxiliary auxtype="sensitive" auxvalue="true"/>
```

(or `auxvalue="1"`). It must appear inside a `<volume>` element. Any
volume with this tag gets a `GenericSD` attached and its hits stream into
the `Hits` TTree. The tag is **inert** in user-written mains that don't
read it — safe to leave in shared GDML files.

To score a volume that already has aux tags for other reasons (e.g.
visualization), just add another `<auxiliary>` element — multiple are
fine.

## Validation

```bash
g4run validate-gdml geometries/<name>.gdml
```

Runs `xmllint --noout` inside the container. Catches XML well-formedness;
**does not** catch material or volume reference errors — those surface
only when Geant4 reads the file. To catch reference errors early, run
the file through a quick simulation (`/geant4-run --events 1`).

## Common mistakes

- Forgetting `lunit` / `unit` on solids and placements → silent mm/rad
  defaults that produce huge or zero-size volumes.
- Two volumes overlapping → Geant4 prints an `[OVLP]` warning; reduce a
  dimension or move the daughter.
- Using a non-NIST material name (`Lead` instead of `G4_Pb`) → run-time
  parse error.
- Putting the aux tag at the wrong nesting level (it must be inside
  `<volume>`, not inside `<structure>` or next to it).

## See also (wiki)

The plugin ships a Geant4-and-physics knowledge base under `wiki/` (see `wiki/index.md` for the full catalog).
**Use the `Read` tool** to pull these pages into context when their topic
is load-bearing for the task at hand:

- `wiki/sources/geant4-code/synthesis/sensitive-detectors-via-gdml-aux.md`
  — the full spine of how the example main wires SDs to GDML
  `<auxiliary>` tags; read this when the user asks "why isn't my volume
  being scored?"
- `wiki/sources/geant4-code/synthesis/g4-src-gdml-auxiliary-walk.md` —
  exact `G4GDMLAuxStructType` API; documents that aux tags do **not**
  inherit from parent → daughter and that nested aux is ignored. Read
  this when designing tag conventions for non-trivial detector trees.
- `wiki/sources/geant4-code/examples/g4-example-persistency-gdml-g01.md`
  — canonical `G4GDMLParser` reader/writer reference; covers feature
  matrix and CDATA escapes. Read this when validating an unfamiliar GDML
  feature.
- `wiki/sources/geant4-code/examples/g4-example-persistency-gdml-g04.md`
  — extended example for wiring SDs via `<auxiliary>` (the pattern this
  plugin's example main implements). Read this when the user wants
  multiple SDs with different score types.
- `wiki/sources/geant4-code/examples/g4-example-geometry-transforms.md`
  — the five Geant4 rotation conventions (active vs passive, etc.); read
  this when a placed daughter is in the wrong orientation.
