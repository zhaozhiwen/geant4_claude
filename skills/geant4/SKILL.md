---
name: geant4
description: Orchestrate the full Geant4 simulation flow (init → detector → preview → build → run → analyze) from a single natural-language user request. Load whenever the user asks to "do", "build", "run", "set up", "create", or "simulate" anything in Geant4 — including one-shot setups like "simulate a 1 GeV e- on a lead block" or "Cherenkov yield from a CO2 radiator". Captures the physics spec, asks targeted clarifying questions when anything required is missing, presents a brief plan for approval, then drives the slash commands in sequence. This is the main entry point for any user who hasn't already picked a single step to run.
---

# geant4 — full-flow orchestrator

Use this skill the moment the user asks for a Geant4 simulation. It is the
front door for everything else this plugin does. The five core slash
commands (`/geant4-claude:geant4-init`, `…detector`, `…build`, `…run`,
`…analyze`) are the *steps*; this skill is the *director* that turns
"simulate X" into a planned sequence of those steps the user has approved.

The default flow this skill drives is the no-C++ path:

```
init → detector → preview → example → (edit macros/run.mac) → build → run → analyze → validate
```

`/geant4-claude:geant4-preview` renders three orthographic PNGs of the
GDML (XY/YZ/XZ) via a host-side matplotlib backend — fast (~1 s), no
container call, supports box/tube/cone/polycone + 3D rotations. The
orchestrator **does** call it automatically between `geant4-detector`
and `geant4-build`, because catching a geometry trap visually saves
the cost of the full build+run cycle. (A second `--backend=raytracer`
backend wraps Geant4's RayTracer for exact-silhouette rendering of
boolean solids; it's alpha and currently hangs in v11.4.) Skip the
preview step if the user explicitly says "no preview" or the geometry
is already known-good from an earlier session.

Bring-your-own-`main.cc` is the alternative the skill picks when the spec
needs hard-coded geometry, custom physics (optical photons, HP neutrons,
scintillation, polarization), or an output schema that isn't `Hits`.

## When to load this skill

Trigger on any of:

- "let's do a Geant4 simulation", "I want to simulate …",
  "build a Geant4 model of …", "run a Cherenkov / dose / scattering /
  calorimetry / shower sim", "set up a Geant4 study of …".
- A physics setup description (beam + target + detector) without "Geant4"
  named explicitly, when Geant4 is the obvious tool.
- "where do I start?" inside a workspace scaffolded by the plugin.

Do **not** load this skill when:

- The user is mid-flow and only wants one step ("just generate GDML for
  X" → use `/geant4-claude:geant4-detector` alone).
- A previous run/build is already failing and the user wants to debug —
  that's a debugging task, not a fresh orchestration.
- The user is iterating on existing geometry/macros for a previous
  simulation; use the single-step commands directly.

## Step 1 — Capture and gap-check the spec

A working simulation needs all six fields below. Read the user's
message and, for each, decide whether they specified it, whether a
default is safe, or whether you must ask.

| Field | What it is | Example |
|---|---|---|
| **Physics goal** | what is being scored or counted | "count Cherenkov photons", "energy deposit per event in the tracker", "dose in tissue" |
| **Geometry** | active volumes: shape, size, material, placement | "1 × 1 × 1 m CO₂ gas radiator at 1 atm, in a 2 m air world" |
| **Beam** | particle, energy, direction, origin, event count | "1 GeV e⁻ along +z from `(0, 0, −0.5 m)`, 1000 events" |
| **Sensitive surfaces / hits** | which volume records hits | "ideal flux backplate downstream of the radiator captures photons" |
| **Output** | ROOT file shape | "per-event photon count + photon hit positions on the backplate" |
| **Analysis** | plots/numbers to produce | "1-D histogram of photons/event; 2-D histogram of photon (x, y) on the backplate" |

The Cherenkov example a user might give —

> *"Create a Cherenkov simulation: a 1 × 1 × 1 m CO₂ gas radiator at 1
> atm, 1 GeV e⁻ beam along the central axis, ideal downstream flux
> backplate collects photons, ROOT output, then use ROOT to analyze
> with a 1-D histogram of photon count and a 2-D histogram of photon
> spatial distribution."*

— has all six fields specified. Anything less needs clarification.

### What must be asked, never guessed

- **Physics goal** — without it you don't know what to score.
- **Beam particle and energy** — too many sensible-but-different defaults.
- **Active material and approximate size** — geometry can't be guessed.
- **Where hits are collected** — which volume is sensitive.

For each missing required field, ask one focused question (use
`AskUserQuestion` for multi-option fields; plain prose for one-line
answers). Tell the user *which* field is missing and *why* a default is
not safe. Do not chain a bunch of guesses together.

### What can default

- World volume: 2 m air box, unless the geometry needs more room.
- Physics list: `FTFP_BERT` for hadronic/EM; **add `G4OpticalPhysics`**
  if the goal mentions Cherenkov, scintillation, or optical photons;
  flag the choice in the plan.
- Event count: 1000.
- Output path: `runs/<id>/hits.root` (or `<output>.root` if the user
  named one).
- Analysis stack: `uproot` + `numpy` + `matplotlib` on the host. If the
  user explicitly says "use ROOT", route through `g4run root <macro>`
  instead and write a `.C` macro under `analysis/`.

### Physics that forces the BYO-`main.cc` alternative

The example main uses `FTFP_BERT` and a generic `Hits` TTree. If the
spec involves any of:

- Optical photons (Cherenkov, scintillation) → `geant4-detector` writes
  the RINDEX GDML (it gates on RINDEX); `src/geant4_claude_main.cc` is
  regenerated from the optical recipe in
  `skills/geant4-physics-list/SKILL.md` (§ "Recipe: regenerating an
  optical-photon main") — apply the recipe in place: edit the three spots
  (physics list, SD class, runtime RINDEX guard) in the existing
  `src/geant4_claude_main.cc`. HP neutrons and non-`Hits` schemas still
  force a fully hand-written main.
- HP neutrons (sub-eV → 20 MeV resonances) → needs `G4HadronPhysicsHP`.
- Polarization, radioactive decay, biasing.
- A non-`Hits` output schema (per-track ntuple, dose grid, etc.).

…then the example main alone can't do it. The plan must say so, and
step 3 of the flow becomes "write a custom `src/<name>.cc` +
`src/CMakeLists.txt`" instead of `/geant4-claude:geant4-example`. For
the optical case the file is fixed: it is an in-place recipe edit of
`src/geant4_claude_main.cc` (the main `geant4-example` drops), not a
freehand new file — tell the user (see the rule in Step 3).

For a Cherenkov spec, the optical path above applies — surface it explicitly in the plan you present.

When writing the custom `main.cc`, follow the same init-order contract
the example main uses: do **not** call `runManager->Initialize()` before
executing the macro. Let the macro own `/run/initialize`. Otherwise the
user can't add `/run/numberOfThreads N` to the macro without hitting
"Illegal application state" — Geant4 only accepts thread count in the
PreInit state, before initialization. Common Geant4 examples (basic/B1,
etc.) do call `Initialize()` in main; we deliberately don't.

### Geometry-sanity gates (run before presenting the plan)

Walk the captured spec against these four checks. If any fail, surface
the issue in **Open questions / risks** with a *concrete fix*, not a
generic warning. "Risks: none" is almost always wrong on a first pass —
one of these usually applies.

1. **Sensor in the forward direct-flux path.** If the sensitive volume
   sits between the beam origin and the primary active target
   (radiator, converter, reflector), it records direct primary flux
   *on top of* whatever the user wanted from the target — usually
   unphysical. Canonical trap: on-axis sensor for a Cherenkov +
   reflector geometry. Propose moving the sensor downstream past the
   target, off-axis, or wrapping the target instead.
2. **Overlapping placements.** Two volumes sharing a face or
   overlapping (e.g., sensor flush against radiator) silently produce
   wrong steps at the boundary. Insert a small gap, or check that the
   sensor is a daughter of the radiator rather than a sibling sitting
   at the same coordinates.
3. **"Sensor" not tagged sensitive.** If the spec names a sensor /
   backplate / detector volume but the user hasn't said which volume
   records hits, confirm before scaffolding — wrong tag = empty `Hits`
   TTree and hours wasted before the user notices.
4. **Beam origin outside or on the world boundary.** Primaries get
   killed before reaching the target if the origin sits on or outside
   the world volume. Pull it inside by ≥1 cm.

## Step 2 — Present a brief plan for approval

Once the spec is complete, show the user a compact plan in this shape
(no headings beyond what's here, no preamble, no "great, here's what
I'll do"):

```
Plan: <one-sentence description of the simulation>

Spec
- Goal:      <…>
- Geometry:  <…>
- Beam:      <…>
- Sensitive: <…>
- Output:    <…>
- Analysis:  <…>

Steps
1. /geant4-claude:geant4-init       — scaffold workspace + cache image
2. /geant4-claude:geant4-detector   — write geometries/<name>.gdml
3. /geant4-claude:geant4-preview    — three orthographic PNGs of the GDML;
     eyeball before building. Skip if the user said "no preview".
4. <one of:>
     /geant4-claude:geant4-example  — drop in the GDML-loading main + macro
     <or> hand-write src/main.cc + src/CMakeLists.txt for <reason>
5. edit macros/<name>.mac for beam particle/energy/event count
6. /geant4-claude:geant4-build
7. /geant4-claude:geant4-run --exe build/<binary> -- \
     geometries/<name>.gdml macros/<name>.mac {run_dir}/<output>.root
8. /geant4-claude:geant4-analyze runs/<id>
     <one line: canned Hits-TTree plot vs. custom uproot script vs. ROOT macro>
9. /geant4-claude:geant4-validate <topic> runs/<id> <topic flags>
     — closure test when an analytic prediction exists (Cherenkov:
       Frank-Tamm). Skip only if no validator covers the physics.

Defaults applied
- <only list defaults you actually filled in; skip this section if none>

Open questions / risks
- <only list real ones — non-default physics needs, missing material
  properties, etc. Don't manufacture caveats.>
```

Then use `AskUserQuestion` with three options:

1. **Approve and run** — proceed with steps 1–9.
2. **Edit the spec** — user wants to change something; loop back to step 1.
3. **Just write the plan, don't run yet** — leaves the plan in the chat
   without executing; useful when the user wants a second look.

Wait for the user's choice. Do not start writing files before approval.

## Step 3 — Execute, in order

Only after the user picks "Approve and run". For each step:

1. Run it.
2. Check its post-condition before moving on:
   - `init` → `CLAUDE.md`, `.gitignore`, `log.md`, `result.md` and the
     six directories exist; `.sif` cached.
   - `detector` → `geometries/<name>.gdml` exists and validates.
   - `preview` → `geometries/<name>.preview/{preview_xy,preview_yz,preview_xz}.png`
     exist. Open the side view (`preview_yz.png`) and confirm the
     captured spec matches what you drew — sensor on the right side
     of the beam, target where you said it'd be, no off-axis offset.
     If the picture disagrees with the spec, **stop and ask** before
     moving to build; that's the whole point of this step.
   - `example` (or hand-written main) → `src/main.cc` (or `src/<name>.cc`)
     and `src/CMakeLists.txt` exist.
   - `build` → `build/<binary>` exists and is executable.
   - `run` → `runs/<id>/{<output>.root, log.txt, config.json}` exist.
   - `analyze` → expected `.png` plots exist under `runs/<id>/`.
   - `validate` → `runs/<id>/validate_<topic>.json` exists; the
     validator's PASS/FAIL block is shown to the user verbatim. On FAIL,
     stop and surface it — do not proceed to the final report as if the
     physics were sound.
3. If a step fails, **stop**. Report the failure (last 20 lines of
   `runs/<id>/log.txt` or the build error) and ask the user how to
   proceed. Do not silently retry, do not paper over the error, do not
   move to the next step.

**Use the slash commands in their documented order.** If you cannot use
a command as documented and must improvise — hand-write what a command
would generate, skip a step, or work around a failure — say so to the
user explicitly: name the command you bypassed, what you did instead,
and why. Never silently substitute your own approach for a documented
command. (For optical specs the documented path is an in-place recipe edit of `src/geant4_claude_main.cc` rather than using `geant4-example` as-is — this is not an improvisation, but still tell the user, since they may expect a fresh file rather than an edited one.)

Maintain the workspace's handoff documents per the rule in
`templates/workspace/CLAUDE.md` non-negotiable #6 — that file is the
authoritative spec; this skill just reminds you to apply it. The
orchestrator-flavored slice of that rule:

- Capture the user's **original request verbatim** (don't paraphrase —
  future readers need to tell what was asked vs. what was inferred).
- Capture the **plan** you presented (the same six-field spec + step
  list shown in step 2 above).
- Capture the user's **decision** (approved as-is, edited spec to …,
  or plan-only).
- Capture the **outcome** (run id, status, one or two lines on what
  happened). Note: `/geant4-claude:geant4-run` already prepended a
  stub block to `log.md` with the run id, status, duration, and
  output paths filled in. Your job is to **find that stub** (it's the
  most recent `## YYYY-MM-DD …` block at the top of `log.md`, with
  `<…>` placeholders in Request / Plan / Decision / Notes) and edit
  the placeholders. Don't write a new section from scratch — that
  duplicates the entry.

Update `result.md` with the key numbers and plot paths after analysis.
The `<!-- ENTRY TEMPLATE -->` comment block at the bottom of `log.md`
is a reference for future sessions; do not modify or delete it.

## Step 4 — Final report

End with a single block:

```
Done.
- Run id:  <id>
- Output:  runs/<id>/<output>.root
- Plots:   runs/<id>/<plot1>.png, runs/<id>/<plot2>.png
- Updated: log.md, result.md

Next: <one concrete suggestion — vary the beam energy, swap the radiator
       material, increase event count, etc.>
```

No "let me know if you have more questions". No emoji. No recap of the
plan — the plots and numbers are the recap.

## Cross-references

- `commands/geant4-detector.md` — natural-language → GDML; this is the
  step that interprets the geometry portion of the spec.
- `skills/geant4-geometry/SKILL.md` — GDML reference (units, materials,
  the `auxiliary sensitive` tag convention).
- `skills/geant4-physics-list/SKILL.md` — picking a physics list,
  including optical photons (Cherenkov) and HP neutrons.
- `skills/geant4-analysis/SKILL.md` — `uproot` recipes; ROOT-macro
  template under `analysis/` when the user asks for ROOT.
- `commands/geant4-validate.md` — physics closure test (Frank-Tamm for
  Cherenkov); the final step of the default flow when a validator
  covers the physics.
- `templates/workspace/CLAUDE.md` — the rules that apply once the
  workspace is scaffolded; loaded into Claude's context for every
  subsequent action in the workspace.
