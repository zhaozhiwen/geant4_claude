# Project log

Chronological notes on this Geant4 simulation project. Prepend the
most recent entry at the top. Each entry captures **what the user
asked for**, **what Claude planned**, **what the user decided**, and
**what actually happened**. Future Claude sessions read this to pick
up where you left off; the user reads it to remember why a particular
run exists.

Use the template below for each new entry. Keep prose tight — link to
specific `runs/<id>/` directories or analysis scripts rather than
quoting their contents.

---

## YYYY-MM-DD HH:MM UTC — <one-line headline>

### Request

> <verbatim user request, in their own words; quote it so future-you
>  can tell what was asked vs. what Claude inferred>

### Plan

- Goal:      <…>
- Geometry:  <…>
- Beam:      <…>
- Sensitive: <…>
- Output:    <…>
- Analysis:  <…>
- Steps:     <e.g. init → detector → example → build → run → analyze>
- Defaults:  <e.g. FTFP_BERT, 2 m air world, 1000 events>
- Risks:     <only if real, e.g. "Cherenkov needs G4OpticalPhysics —
              going BYO main.cc">

### Decision

<approved as-is | edited spec to <…> | wrote plan only, did not run>

### Outcome

- Run id:  `runs/<id>` (or "n/a — plan only")
- Status:  <succeeded | failed at <step> with <reason>>
- Notes:   <one or two lines: what worked, what surprised, what's next>
