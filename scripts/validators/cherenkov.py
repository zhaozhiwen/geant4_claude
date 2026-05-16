#!/usr/bin/env python3
"""Cherenkov closure validator.

Compares the simulated optical-photon yield (per event, in a runs/<id>/
output ROOT file) against the Frank-Tamm prediction. Writes a JSON
summary alongside the input and exits non-zero on FAIL so CI /
orchestrator gates can branch on it.

Two refractive-index modes:

  Constant n (default — pass --refractive-index N):
    N/event = 2*pi*alpha*L * (1/lam_min - 1/lam_max) * (1 - 1/(beta^2 * n^2))

  Wavelength-dependent n (recommended — pass --rindex-from-gdml + --rindex-material):
    Reads the RINDEX matrix out of the GDML material, then trapezoidally
    integrates the Frank-Tamm differential
       dN/(dx dE) = (alpha / hbar c) * (1 - 1/(beta^2 * n^2(E)))
    over the energy window E in [hc/lam_max .. hc/lam_min]. Removes the
    2-5% bias of feeding a single index for a real dispersive radiator.

Tolerance is 3 sigma where sigma = sqrt(predicted / n_events) — Poisson
counting on the mean over n_events.

Usage:
    python3 cherenkov.py <run_dir>
        # Pick ONE refractive-index source:
        --refractive-index 1.000449
        # ...or:
        --rindex-from-gdml geometries/radiator.gdml --rindex-material G4_CARBON_DIOXIDE
        --radiator-length 1m
        [--wavelength-min 200nm] [--wavelength-max 800nm]
        [--beam-beta 1.0]
        [--tree Hits]
        [--root <explicit.root>]

    Schema modes (pick one):

      Default — filtered counting, for the shipped example main.cc which
      writes per-hit rows with (event, pdg, ...) branches. Override the
      branch names if your TTree uses different ones:
        [--event-branch event] [--pdg-branch pdg] [--photon-pdg -22]

      Per-event count — for a custom main.cc that already writes one row
      per event with a precomputed photon count. Pass the branch name and
      skip the filtered path entirely:
        --count-branch n_photons
"""

import argparse
import json
import math
import sys
import xml.etree.ElementTree as ET
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


# Energy parsing (for GDML RINDEX matrix values) -----------------------------

_ENERGY_UNITS_EV = {
    "eV": 1.0,
    "keV": 1e3,
    "MeV": 1e6,
    "GeV": 1e9,
}


def parse_energy_eV(tok: str) -> float:
    """Parse one GDML matrix energy token into eV.

    GDML matrix values may carry an explicit unit, written as a Geant4
    unit expression (`1.5*eV`, `1.5eV`). A *bare* number is in Geant4
    internal units, where energy is MeV — that is the convention the
    plugin's own generated GDML uses, so it must keep working.
    """
    t = tok.strip().replace("*", "")
    for unit in sorted(_ENERGY_UNITS_EV, key=len, reverse=True):
        if t.endswith(unit):
            return float(t[: -len(unit)]) * _ENERGY_UNITS_EV[unit]
    # Bare number: Geant4 internal energy unit is MeV.
    return float(t) * _ENERGY_UNITS_EV["MeV"]


# ROOT reading ---------------------------------------------------------------


def _import_uproot():
    try:
        import uproot  # noqa: F401
        import numpy  # noqa: F401
    except ImportError as e:
        raise SystemExit(
            f"[validate-cherenkov] missing dep: {e}. "
            "Run this through /geant4-claude:geant4-validate, which resolves "
            "a Python with uproot+numpy (host or the plugin-managed venv). "
            "Do not pip install --user."
        )
    import uproot
    import numpy as np
    return uproot, np


def _open_tree(root_path: Path, tree_name: str):
    uproot, _ = _import_uproot()
    f = uproot.open(root_path)
    keys = {k.split(";")[0] for k in f.keys()}
    if tree_name not in keys:
        f.close()
        raise SystemExit(
            f"[validate-cherenkov] tree '{tree_name}' not in "
            f"{root_path}; available: {sorted(keys)}"
        )
    return f, f[tree_name]


def read_photons_filtered(
    root_path: Path,
    tree_name: str,
    event_branch: str,
    pdg_branch: str,
    photon_pdg: int,
):
    """Per-hit schema: filter rows where `pdg_branch == photon_pdg`, then
    histogram by `event_branch` to get photons-per-event.

    Returns (photons_per_event_array, n_events)."""
    _, np = _import_uproot()
    f, tree = _open_tree(root_path, tree_name)
    try:
        branches = set(tree.keys())
        for required in (event_branch, pdg_branch):
            if required not in branches:
                raise SystemExit(
                    f"[validate-cherenkov] tree '{tree_name}' lacks "
                    f"'{required}' branch; got {sorted(branches)}"
                )
        events = tree[event_branch].array(library="np")
        pdgs = tree[pdg_branch].array(library="np")
    finally:
        f.close()

    if len(events) == 0:
        return np.zeros(0, dtype=int), 0

    mask = pdgs == photon_pdg
    photon_events = events[mask]
    n_events = int(events.max()) + 1
    counts = np.bincount(photon_events, minlength=n_events)
    return counts, n_events


def read_photons_direct(
    root_path: Path,
    tree_name: str,
    count_branch: str,
):
    """Per-event schema: one row per event, with `count_branch` holding the
    photon count directly. Returns (photons_per_event_array, n_events)."""
    _, np = _import_uproot()
    f, tree = _open_tree(root_path, tree_name)
    try:
        branches = set(tree.keys())
        if count_branch not in branches:
            raise SystemExit(
                f"[validate-cherenkov] tree '{tree_name}' lacks "
                f"'{count_branch}' branch; got {sorted(branches)}"
            )
        counts = tree[count_branch].array(library="np")
    finally:
        f.close()

    counts = np.asarray(counts, dtype=np.int64)
    return counts, int(len(counts))


# Frank-Tamm prediction ------------------------------------------------------


_ALPHA = 1.0 / 137.035999  # fine-structure constant
_HC_EV_M = 1.23984198e-6   # h*c in eV*m (so E_eV = HC/lam_m)


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
    inv_lam = 1.0 / wavelength_min_m - 1.0 / wavelength_max_m
    bn2 = beta * beta * refractive_index * refractive_index
    if bn2 <= 1.0:
        # Below threshold — no Cherenkov radiation.
        return 0.0
    return 2.0 * math.pi * _ALPHA * length_m * inv_lam * (1.0 - 1.0 / bn2)


# Wavelength-dependent path -------------------------------------------------


def _drop_ns(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag


def parse_rindex_from_gdml(gdml_path: Path, material_name: str) -> list[tuple[float, float]]:
    """Pull the RINDEX matrix for a named material out of a GDML file.

    Returns a list of (energy_eV, n) sorted by ascending energy.

    The energy column is parsed per-token via ``parse_energy_eV``: a
    bare number is Geant4-internal MeV (the convention the plugin's own
    generated GDML uses), while an explicit unit expression such as
    ``1.5*eV`` — common in hand-written or imported GDML — is honored
    rather than crashing ``float()`` or being silently scaled by 1e6.
    """
    try:
        tree = ET.parse(gdml_path)
    except ET.ParseError as e:
        raise SystemExit(f"[validate-cherenkov] GDML parse error in {gdml_path}: {e}")
    root = tree.getroot()

    # Find the material element.
    target = None
    for el in root.iter():
        if _drop_ns(el.tag) == "material" and el.get("name") == material_name:
            target = el
            break
    if target is None:
        raise SystemExit(
            f"[validate-cherenkov] material '{material_name}' not found in {gdml_path}. "
            "Check the name matches the <material name='...'> attribute."
        )

    rindex_ref = None
    for child in target:
        if _drop_ns(child.tag) == "property" and child.get("name") == "RINDEX":
            rindex_ref = child.get("ref")
            break
    if rindex_ref is None:
        raise SystemExit(
            f"[validate-cherenkov] material '{material_name}' has no RINDEX property "
            f"in {gdml_path}. Cherenkov needs RINDEX; add a <matrix> + "
            "<property name='RINDEX' ref='...'/> or fall back to --refractive-index."
        )

    matrix = None
    for el in root.iter():
        if _drop_ns(el.tag) == "matrix" and el.get("name") == rindex_ref:
            matrix = el
            break
    if matrix is None:
        raise SystemExit(
            f"[validate-cherenkov] matrix '{rindex_ref}' (referenced by "
            f"material '{material_name}') not found in {gdml_path}."
        )

    coldim = int(matrix.get("coldim", "2"))
    if coldim != 2:
        raise SystemExit(
            f"[validate-cherenkov] unexpected coldim={coldim} for matrix "
            f"'{rindex_ref}' — RINDEX is a 2-column (energy, n) matrix."
        )
    toks = (matrix.get("values") or "").split()
    if len(toks) < 4 or len(toks) % 2 != 0:
        raise SystemExit(
            f"[validate-cherenkov] matrix '{rindex_ref}' has {len(toks)} values; "
            "expected an even count >= 4 (at least 2 (energy, n) pairs)."
        )
    try:
        pairs = sorted(
            (parse_energy_eV(toks[i]), float(toks[i + 1]))
            for i in range(0, len(toks), 2)
        )
    except ValueError as e:
        raise SystemExit(
            f"[validate-cherenkov] could not parse RINDEX matrix "
            f"'{rindex_ref}' values ({e}). Expected (energy, n) pairs; "
            "energy may carry a Geant4 unit (e.g. '2.0*eV')."
        )
    return pairs


def frank_tamm_yield_table(
    length_m: float,
    rindex_table: list[tuple[float, float]],
    wavelength_min_m: float,
    wavelength_max_m: float,
    beta: float,
) -> tuple[float, float, tuple[float, float], tuple[float, float]]:
    """Wavelength-dependent Frank-Tamm yield via trapezoidal integration
    of dN/(dx dE) over E in [hc/lam_max .. hc/lam_min].

    Returns (yield_per_event, n_effective_dE_weighted,
             (E_min_eV, E_max_eV), (n_at_E_min, n_at_E_max)).
    """
    if not rindex_table:
        return 0.0, 1.0, (0.0, 0.0), (1.0, 1.0)
    pts = sorted(rindex_table)
    E_min = _HC_EV_M / wavelength_max_m  # eV (longer wavelength = lower energy)
    E_max = _HC_EV_M / wavelength_min_m

    def n_at(E: float) -> float:
        if E <= pts[0][0]:
            return pts[0][1]
        if E >= pts[-1][0]:
            return pts[-1][1]
        for (E0, n0), (E1, n1) in zip(pts, pts[1:]):
            if E0 <= E <= E1:
                return n0 + (n1 - n0) * (E - E0) / (E1 - E0)
        return pts[-1][1]

    # Integration grid: clipped matrix energies + window endpoints.
    interior = sorted({E for (E, _) in pts if E_min < E < E_max})
    grid = sorted({E_min, E_max, *interior})

    integral = 0.0       # ∫ (1 - 1/(β² n²(E))) dE
    integral_n = 0.0     # ∫ n(E) dE  (for reporting an effective n)
    for E0, E1 in zip(grid, grid[1:]):
        n0, n1 = n_at(E0), n_at(E1)
        bn2_0 = beta * beta * n0 * n0
        bn2_1 = beta * beta * n1 * n1
        f0 = (1.0 - 1.0 / bn2_0) if bn2_0 > 1.0 else 0.0
        f1 = (1.0 - 1.0 / bn2_1) if bn2_1 > 1.0 else 0.0
        dE = E1 - E0
        integral += 0.5 * dE * (f0 + f1)
        integral_n += 0.5 * dE * (n0 + n1)

    yield_per_event = (2.0 * math.pi * _ALPHA * length_m / _HC_EV_M) * integral
    n_eff = integral_n / (E_max - E_min) if E_max > E_min else pts[0][1]
    return yield_per_event, n_eff, (E_min, E_max), (n_at(E_min), n_at(E_max))


# Main -----------------------------------------------------------------------


def main(argv=None) -> int:
    p = argparse.ArgumentParser(
        description="Cherenkov closure test (Frank-Tamm vs simulation)."
    )
    p.add_argument("run_dir", help="Path to runs/<id>/")
    p.add_argument("--radiator-length", required=True,
                   help="Radiator path length (e.g. '1m', '50cm')")
    # Refractive-index source: --refractive-index OR --rindex-from-gdml,
    # not both. Validated post-parse so the error message is friendlier
    # than argparse's mutually-exclusive default.
    p.add_argument("--refractive-index", type=float, default=None,
                   help="Constant refractive index (use when no GDML matrix is available).")
    p.add_argument("--rindex-from-gdml", default=None,
                   help="GDML file containing the radiator material's RINDEX matrix.")
    p.add_argument("--rindex-material", default=None,
                   help="Name of the radiator material in --rindex-from-gdml. Required with it.")
    p.add_argument("--wavelength-min", default="200nm")
    p.add_argument("--wavelength-max", default="800nm")
    p.add_argument("--beam-beta", default=1.0, type=float,
                   help="v/c of the primary (default 1.0 — ultra-relativistic)")
    p.add_argument("--tree", default="Hits",
                   help="Name of the TTree to read")
    # Filtered (per-hit) schema: photons counted by pdg match over hit rows.
    p.add_argument("--event-branch", default="event",
                   help="Branch holding the event index (filtered mode)")
    p.add_argument("--pdg-branch", default="pdg",
                   help="Branch holding the particle PDG code (filtered mode)")
    p.add_argument("--photon-pdg", default=-22, type=int,
                   help="PDG code for optical photons (Geant4: -22). "
                        "Filtered mode only.")
    # Direct (per-event) schema: one row per event with a precomputed count.
    p.add_argument("--count-branch", default=None,
                   help="Branch holding per-event photon counts. If set, "
                        "switches to per-event schema and ignores "
                        "--event-branch / --pdg-branch / --photon-pdg.")
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

    # Resolve refractive-index source.
    using_gdml_rindex = args.rindex_from_gdml is not None
    if using_gdml_rindex and args.refractive_index is not None:
        print("[validate-cherenkov] pass only one of --refractive-index or "
              "--rindex-from-gdml, not both.", file=sys.stderr)
        return 2
    if not using_gdml_rindex and args.refractive_index is None:
        print("[validate-cherenkov] no refractive index given. Pass either "
              "--refractive-index <float> or "
              "--rindex-from-gdml <file> --rindex-material <name>.",
              file=sys.stderr)
        return 2
    if using_gdml_rindex and not args.rindex_material:
        print("[validate-cherenkov] --rindex-from-gdml requires --rindex-material "
              "(the GDML material whose RINDEX should be read).", file=sys.stderr)
        return 2

    rindex_table = None
    if using_gdml_rindex:
        rindex_table = parse_rindex_from_gdml(
            Path(args.rindex_from_gdml), args.rindex_material,
        )

    if args.count_branch is not None:
        counts, n_events = read_photons_direct(
            root_path, args.tree, args.count_branch
        )
        schema_mode = "direct"
    else:
        counts, n_events = read_photons_filtered(
            root_path, args.tree, args.event_branch, args.pdg_branch,
            args.photon_pdg
        )
        schema_mode = "filtered"
    if n_events == 0:
        print(f"[validate-cherenkov] no events in {root_path}", file=sys.stderr)
        return 1

    observed_mean = float(counts.mean())
    observed_std = float(counts.std(ddof=1)) if n_events > 1 else 0.0

    # Predict yield, picking the integration mode.
    rindex_extra = {}
    if using_gdml_rindex:
        predicted, n_eff, (E_min_eV, E_max_eV), (n_at_E_min, n_at_E_max) = \
            frank_tamm_yield_table(
                length_m=L,
                rindex_table=rindex_table,
                wavelength_min_m=lam_min,
                wavelength_max_m=lam_max,
                beta=args.beam_beta,
            )
        rindex_extra = {
            "n_effective": n_eff,
            "n_at_lam_max": n_at_E_min,  # E_min ↔ lam_max
            "n_at_lam_min": n_at_E_max,  # E_max ↔ lam_min
            "E_min_eV": E_min_eV,
            "E_max_eV": E_max_eV,
            "rindex_table_eV": rindex_table,
        }
        n_for_threshold = n_eff
    else:
        predicted = frank_tamm_yield(
            length_m=L,
            refractive_index=args.refractive_index,
            wavelength_min_m=lam_min,
            wavelength_max_m=lam_max,
            beta=args.beam_beta,
        )
        n_for_threshold = args.refractive_index

    if predicted <= 0:
        print(f"[validate-cherenkov] predicted yield is 0 — "
              f"beam is below Cherenkov threshold (beta*n_eff = "
              f"{args.beam_beta*n_for_threshold:.4f}; need > 1)",
              file=sys.stderr)
        return 2

    sigma = math.sqrt(predicted / n_events)
    delta = abs(observed_mean - predicted)
    passed = delta < args.tolerance_sigma * sigma
    n_sigma = delta / sigma if sigma > 0 else float("inf")

    print(f"[validate-cherenkov] {root_path}")
    if using_gdml_rindex:
        n_eff = rindex_extra["n_effective"]
        n_lo, n_hi = rindex_extra["n_at_lam_max"], rindex_extra["n_at_lam_min"]
        print(f"  rindex source:          {args.rindex_from_gdml}::{args.rindex_material}")
        print(f"    n_effective:          {n_eff:.6f}  (dE-weighted over window)")
        print(f"    n range over window:  {n_lo:.6f} → {n_hi:.6f}")
    else:
        print(f"  rindex source:          constant n = {args.refractive_index}")
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
            "rindex_source": (
                f"gdml:{args.rindex_from_gdml}::{args.rindex_material}"
                if using_gdml_rindex else "constant"
            ),
            "refractive_index": (
                rindex_extra["n_effective"] if using_gdml_rindex
                else args.refractive_index
            ),
            "rindex_table_eV": rindex_extra.get("rindex_table_eV"),
            "rindex_at_lam_min": rindex_extra.get("n_at_lam_min"),
            "rindex_at_lam_max": rindex_extra.get("n_at_lam_max"),
            "wavelength_min_m": lam_min,
            "wavelength_max_m": lam_max,
            "beam_beta": args.beam_beta,
            "tree": args.tree,
            "schema_mode": schema_mode,
            "event_branch": args.event_branch if schema_mode == "filtered" else None,
            "pdg_branch": args.pdg_branch if schema_mode == "filtered" else None,
            "photon_pdg": args.photon_pdg if schema_mode == "filtered" else None,
            "count_branch": args.count_branch if schema_mode == "direct" else None,
        },
    }
    summary_path = run_dir / "validate_cherenkov.json"
    summary_path.write_text(json.dumps(summary, indent=2))
    print(f"  summary:                {summary_path}")

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
