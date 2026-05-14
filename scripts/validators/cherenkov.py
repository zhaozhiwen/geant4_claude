#!/usr/bin/env python3
"""Cherenkov closure validator.

Compares the simulated optical-photon yield (per event, in a runs/<id>/
output ROOT file) against the Frank-Tamm prediction for a constant-n
radiator. Writes a JSON summary alongside the input and exits non-zero
on FAIL so CI / orchestrator gates can branch on it.

Frank-Tamm (per unit length, constant n, over [lam_min, lam_max]):
    N/event = 2*pi*alpha*L * (1/lam_min - 1/lam_max) * (1 - 1/(beta^2 * n^2))

Tolerance is 3 sigma where sigma = sqrt(predicted / n_events) — Poisson
counting on the mean over n_events.

Usage:
    python3 cherenkov.py <run_dir>
        --radiator-length 1m
        --refractive-index 1.000449
        [--wavelength-min 200nm] [--wavelength-max 800nm]
        [--beam-beta 1.0]
        [--photon-pdg -22]
        [--tree Hits]
        [--root <explicit.root>]
"""

import argparse
import json
import math
import sys
from pathlib import Path


# Length parsing -------------------------------------------------------------

_LENGTH_UNITS = {
    "m": 1.0,
    "cm": 1e-2,
    "mm": 1e-3,
    "um": 1e-6,
    "nm": 1e-9,
}


def parse_length(s: str) -> float:
    """Parse a length with unit suffix into meters.

    Accepts '1m', '1.5cm', '50mm', '500nm'. Bare numbers are interpreted
    as meters. Raises ValueError on bad input.
    """
    s = s.strip()
    # Sort by suffix length descending so 'cm', 'mm', 'um', 'nm' match before 'm'.
    for unit in sorted(_LENGTH_UNITS, key=len, reverse=True):
        if s.endswith(unit):
            return float(s[: -len(unit)]) * _LENGTH_UNITS[unit]
    return float(s)


# ROOT reading ---------------------------------------------------------------


def read_photons_per_event(root_path: Path, tree_name: str, photon_pdg: int):
    """Return (photons_per_event_array, n_events). Photons are counted by
    PDG match in the named tree."""
    try:
        import uproot
        import numpy as np
    except ImportError as e:
        raise SystemExit(
            f"[validate-cherenkov] missing dep: {e}. "
            "Install with: pip install --user uproot numpy"
        )

    with uproot.open(root_path) as f:
        keys = {k.split(";")[0] for k in f.keys()}
        if tree_name not in keys:
            raise SystemExit(
                f"[validate-cherenkov] tree '{tree_name}' not in "
                f"{root_path}; available: {sorted(keys)}"
            )
        tree = f[tree_name]
        branches = set(tree.keys())
        for required in ("event", "pdg"):
            if required not in branches:
                raise SystemExit(
                    f"[validate-cherenkov] tree '{tree_name}' lacks "
                    f"'{required}' branch; got {sorted(branches)}"
                )
        events = tree["event"].array(library="np")
        pdgs = tree["pdg"].array(library="np")

    if len(events) == 0:
        return np.zeros(0, dtype=int), 0

    mask = pdgs == photon_pdg
    photon_events = events[mask]
    n_events = int(events.max()) + 1
    counts = np.bincount(photon_events, minlength=n_events)
    return counts, n_events


# Frank-Tamm prediction ------------------------------------------------------


def frank_tamm_yield(
    length_m: float,
    refractive_index: float,
    wavelength_min_m: float,
    wavelength_max_m: float,
    beta: float,
) -> float:
    """Frank-Tamm photon yield per event for a constant-n radiator.

    Returns the integrated yield N/event (dimensionless) over a track of
    length L in a radiator of refractive index n, summed over wavelengths
    in [lam_min, lam_max].
    """
    alpha = 1.0 / 137.035999  # fine-structure constant
    inv_lam = 1.0 / wavelength_min_m - 1.0 / wavelength_max_m
    bn2 = beta * beta * refractive_index * refractive_index
    if bn2 <= 1.0:
        # Below threshold — no Cherenkov radiation.
        return 0.0
    return 2.0 * math.pi * alpha * length_m * inv_lam * (1.0 - 1.0 / bn2)


# Main -----------------------------------------------------------------------


def main(argv=None) -> int:
    p = argparse.ArgumentParser(
        description="Cherenkov closure test (Frank-Tamm vs simulation)."
    )
    p.add_argument("run_dir", help="Path to runs/<id>/")
    p.add_argument("--radiator-length", required=True,
                   help="Radiator path length (e.g. '1m', '50cm')")
    p.add_argument("--refractive-index", required=True, type=float,
                   help="Refractive index of the radiator (constant n)")
    p.add_argument("--wavelength-min", default="200nm")
    p.add_argument("--wavelength-max", default="800nm")
    p.add_argument("--beam-beta", default=1.0, type=float,
                   help="v/c of the primary (default 1.0 — ultra-relativistic)")
    p.add_argument("--photon-pdg", default=-22, type=int,
                   help="PDG code for optical photons (Geant4: -22)")
    p.add_argument("--tree", default="Hits",
                   help="Name of the TTree to read")
    p.add_argument("--root", default=None,
                   help="Explicit ROOT file path; otherwise autodetect")
    p.add_argument("--tolerance-sigma", default=3.0, type=float,
                   help="PASS if |observed - predicted| < N sigma (default 3)")
    args = p.parse_args(argv)

    run_dir = Path(args.run_dir)
    if not run_dir.is_dir():
        print(f"[validate-cherenkov] not a directory: {run_dir}", file=sys.stderr)
        return 2

    if args.root:
        root_path = Path(args.root)
    else:
        candidates = sorted(run_dir.glob("*.root"))
        if not candidates:
            print(f"[validate-cherenkov] no .root file in {run_dir}",
                  file=sys.stderr)
            return 2
        if len(candidates) > 1:
            print(f"[validate-cherenkov] multiple .root files in {run_dir} — "
                  f"pass --root explicitly: "
                  f"{[c.name for c in candidates]}", file=sys.stderr)
            return 2
        root_path = candidates[0]

    L = parse_length(args.radiator_length)
    lam_min = parse_length(args.wavelength_min)
    lam_max = parse_length(args.wavelength_max)
    if lam_min >= lam_max:
        print(f"[validate-cherenkov] wavelength_min ({lam_min}) "
              f">= wavelength_max ({lam_max})", file=sys.stderr)
        return 2

    counts, n_events = read_photons_per_event(
        root_path, args.tree, args.photon_pdg
    )
    if n_events == 0:
        print(f"[validate-cherenkov] no events in {root_path}", file=sys.stderr)
        return 1

    observed_mean = float(counts.mean())
    observed_std = float(counts.std(ddof=1)) if n_events > 1 else 0.0

    predicted = frank_tamm_yield(
        length_m=L,
        refractive_index=args.refractive_index,
        wavelength_min_m=lam_min,
        wavelength_max_m=lam_max,
        beta=args.beam_beta,
    )
    if predicted <= 0:
        print(f"[validate-cherenkov] predicted yield is 0 — "
              f"beam is below Cherenkov threshold (beta*n = "
              f"{args.beam_beta*args.refractive_index:.4f}; need > 1)",
              file=sys.stderr)
        return 2

    sigma = math.sqrt(predicted / n_events)
    delta = abs(observed_mean - predicted)
    passed = delta < args.tolerance_sigma * sigma
    n_sigma = delta / sigma if sigma > 0 else float("inf")

    print(f"[validate-cherenkov] {root_path}")
    print(f"  predicted (Frank-Tamm): {predicted:.4f} photons/event")
    print(f"  observed:               {observed_mean:.4f} +/- {observed_std:.4f}")
    print(f"  events:                 {n_events}")
    print(f"  |delta|:                {delta:.4f} ({n_sigma:.2f} sigma)")
    print(f"  tolerance:              {args.tolerance_sigma} sigma "
          f"= {args.tolerance_sigma*sigma:.4f}")
    print(f"  RESULT:                 {'PASS' if passed else 'FAIL'}")

    summary = {
        "validator": "cherenkov",
        "root_file": str(root_path),
        "predicted_per_event": predicted,
        "observed_mean": observed_mean,
        "observed_std": observed_std,
        "n_events": n_events,
        "sigma": sigma,
        "delta": delta,
        "n_sigma": n_sigma,
        "tolerance_sigma": args.tolerance_sigma,
        "pass": passed,
        "parameters": {
            "radiator_length_m": L,
            "refractive_index": args.refractive_index,
            "wavelength_min_m": lam_min,
            "wavelength_max_m": lam_max,
            "beam_beta": args.beam_beta,
            "photon_pdg": args.photon_pdg,
            "tree": args.tree,
        },
    }
    summary_path = run_dir / "validate_cherenkov.json"
    summary_path.write_text(json.dumps(summary, indent=2))
    print(f"  summary:                {summary_path}")

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
