#!/usr/bin/env python3
"""Default plot for a run produced by the example main: per-event
energy-deposit histogram.

Usage: python analysis/example.py runs/<run_id>

Reads runs/<run_id>/hits.root (TTree 'Hits') and writes edep_hist.png
next to it. Schema-aware only of the example's TTree — your own
analysis goes in analysis/<run_id>.py.
"""
import pathlib
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import uproot


def main(run_dir: pathlib.Path) -> None:
    root_path = run_dir / "hits.root"
    with uproot.open(root_path) as f:
        t = f["Hits"]
        event = t["event"].array(library="np")
        edep = t["edep"].array(library="np")  # MeV

    if len(event) == 0:
        print(f"WARNING: {root_path} has no entries")
        return

    n_events = int(event.max() + 1)
    per_event = np.bincount(event, weights=edep, minlength=n_events)

    fig, ax = plt.subplots()
    ax.hist(per_event, bins=50)
    ax.set_xlabel("Energy deposit per event [MeV]")
    ax.set_ylabel("Events")
    ax.set_title(f"{run_dir.name} — {n_events} events, {len(edep)} hits")
    out = run_dir / "edep_hist.png"
    fig.savefig(out, dpi=120)

    print(f"wrote {out}")
    print(f"  events     = {n_events}")
    print(f"  total hits = {len(edep)}")
    print(f"  mean edep  = {per_event.mean():.4g} MeV/event")
    print(f"  std edep   = {per_event.std():.4g} MeV/event")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} runs/<run_id>")
    main(pathlib.Path(sys.argv[1]))
