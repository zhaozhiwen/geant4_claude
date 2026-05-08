---
name: geant4-analysis
description: Read the Hits TTree with uproot/numpy and make the standard plots (per-event edep, hit map, per-volume sums). Load when writing or running anything in analysis/ or interpreting runs/<id>/hits.root.
---

# geant4-analysis

The plugin's default analysis stack is **`uproot` + `numpy` +
`matplotlib`** on the host — no ROOT install required. Anything that
genuinely needs ROOT (TBrowser, TMVA, RooFit) runs in the container via
`g4run root <macro>`.

## TTree contract

`runs/<id>/hits.root` contains exactly one TTree, `Hits`, with these
branches:

| Branch  | Type     | Unit | Meaning |
|---------|----------|------|---------|
| `event` | `int32`  | —    | Event ID (0-indexed). |
| `volume`| `string` (char[64]) | — | Logical-volume name where the hit was recorded. |
| `edep`  | `float64`| MeV  | Energy deposited in this step. |
| `x,y,z` | `float64`| mm   | Pre-step position in global coordinates. |
| `t`     | `float64`| ns   | Pre-step global time. |
| `pdg`   | `int32`  | —    | PDG code of the depositing track. |

One row per non-zero-edep step. To get per-event quantities, group by
`event`.

The companion `runs/<id>/config.json` carries the run's provenance
(`particle`, `energy_MeV`, `n_events`, image digest, etc.). Read it
instead of hard-coding event counts.

## Install

```bash
pip install --user uproot numpy matplotlib
```

If the user wants isolation (recommended), create a workspace venv:

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install uproot numpy matplotlib
```

The plugin does not auto-install — pick your poison and add it to the
project's normal Python flow.

## Recipe: read the tree

```python
import json, pathlib
import uproot, numpy as np

run_dir = pathlib.Path("runs/<id>")
cfg = json.loads((run_dir / "config.json").read_text())

with uproot.open(run_dir / "hits.root") as f:
    t = f["Hits"]
    arrs = t.arrays(["event", "volume", "edep", "x", "y", "z", "t", "pdg"],
                    library="np")
event = arrs["event"]
edep  = arrs["edep"]
# arrs["volume"] is a numpy array of bytes; decode if needed:
volume = np.array([v.decode() for v in arrs["volume"]])
```

For large files use `t.iterate(step_size="100 MB", library="np")`.

## Recipe: per-event energy deposit

```python
n_events  = cfg["n_events"]
per_event = np.bincount(event, weights=edep, minlength=n_events)
# per_event[i] is total MeV deposited in event i
```

Histogram:

```python
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.hist(per_event, bins=50)
ax.set_xlabel("Energy deposit per event [MeV]")
ax.set_ylabel("Events")
ax.set_title(f"{cfg['particle']} @ {cfg['energy_MeV']} MeV, "
             f"{n_events} events")
fig.savefig(run_dir / "edep_hist.png", dpi=120)
```

## Recipe: per-volume summary

```python
import collections
totals = collections.Counter()
for v, e in zip(volume, edep):
    totals[v] += e
for name, mev in sorted(totals.items(), key=lambda kv: -kv[1]):
    print(f"{name:30s} {mev:12.3g} MeV  ({mev/n_events:.3g} MeV/event)")
```

## Recipe: 2-D hit map (transverse to beam)

```python
fig, ax = plt.subplots()
ax.hexbin(arrs["x"], arrs["y"], C=arrs["edep"], reduce_C_function=np.sum,
          gridsize=80, cmap="viridis")
ax.set_xlabel("x [mm]"); ax.set_ylabel("y [mm]")
ax.set_aspect("equal")
ax.set_title("Edep hit map (Σ over all hits)")
fig.savefig(run_dir / "xy_map.png", dpi=120)
```

For longitudinal showers (z vs energy), do the same with `arrs["z"]`
and a 1-D histogram.

## When to drop into ROOT instead

- Interactive browsing of a huge tree (`TBrowser`).
- ROOT-specific fitting (`RooFit`, `TMVA`).
- Re-running a JLab-flavored `.C` macro that someone already wrote.

```bash
g4run root 'mymacro.C("runs/<id>/hits.root")'
```

Even then, prefer producing the *plot* with matplotlib if the script
will be re-run by other people who may not have ROOT.

## Pitfalls

- Forgetting that `volume` is bytes, not str — fix with `.decode()`.
- Treating each row as an event. Each row is a *step*; use
  `np.bincount` to aggregate.
- Using `t.array("event")` (singular) vs `t.arrays([...])` — both work,
  the plural is faster when reading several branches.
- Loading the whole tree into memory for huge runs — use `iterate`
  instead and accumulate per-event sums online.
- Comparing edep to gun energy without accounting for escape. A 1 GeV
  e- in a 1×1×10 cm Pb block deposits ~600 MeV (rest leaks
  transversely); that is *not* a bug.
