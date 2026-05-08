#!/usr/bin/env python3
"""Default plot: per-event energy deposit histogram for a single run.

Usage: python analysis/example.py runs/<run_id>

Reads runs/<run_id>/hits.root (TTree 'Hits') and writes edep_hist.png next
to it. Run config (particle, energy, n_events) comes from config.json — the
provenance record produced by /geant4-run.
"""
import json
import pathlib
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import uproot


def main(run_dir: pathlib.Path) -> None:
    cfg = json.loads((run_dir / "config.json").read_text())
    with uproot.open(run_dir / "hits.root") as f:
        t = f["Hits"]
        event = t["event"].array(library="np")
        edep = t["edep"].array(library="np")  # MeV

    n_events = cfg["n_events"]
    per_event = np.bincount(event, weights=edep, minlength=n_events)

    fig, ax = plt.subplots()
    ax.hist(per_event, bins=50)
    ax.set_xlabel("Energy deposit per event [MeV]")
    ax.set_ylabel("Events")
    ax.set_title(
        f"{cfg['particle']} @ {cfg['energy_MeV']} MeV, {n_events} events"
    )
    out = run_dir / "edep_hist.png"
    fig.savefig(out, dpi=120)

    print(f"wrote {out}")
    print(f"  mean = {per_event.mean():.4g} MeV")
    print(f"  std  = {per_event.std():.4g} MeV")
    print(f"  hits = {len(edep)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} runs/<run_id>")
    main(pathlib.Path(sys.argv[1]))
