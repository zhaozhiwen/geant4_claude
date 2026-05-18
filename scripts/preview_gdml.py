#!/usr/bin/env python3
"""Headless GDML geometry preview via matplotlib (sketch backend).

Reads a GDML file, walks <solids> + <structure>, transforms every placed
physvol into world coordinates, and writes three orthographic PNG
projections (XY, YZ, XZ) to <out_dir>/. Pure host-side Python — no
container or Geant4 install needed. Stdlib XML parser; matplotlib is the
only external dep.

Supported solids: box, tube, cone, polycone. Other solid types are
drawn as their axis-aligned bounding box with a "!" badge so the user
sees that something exists there without it silently going missing.
Translation and 3D rotation (full 3x3 matrix from Euler X-Y-Z) are
honored.

Out of scope on purpose:
  - Boolean solids (union/subtraction/intersection). These render as
    bounding boxes — for full booleans, use --backend=raytracer.
  - Replica / parameterised volumes.
  - Curved cross-sections drawn as curves. We sample 32 azimuthal
    points per circular slice and connect them with line segments,
    so a tube looks like a hexa-decagon. Good enough for sanity
    checking the layout; not a CAD viewer.

Usage:
    python3 preview_gdml.py <input.gdml> <out_dir>

Outputs:
    <out_dir>/preview_xy.png   end view (camera at +z, looking at origin)
    <out_dir>/preview_yz.png   side view (camera at +x)
    <out_dir>/preview_xz.png   top view  (camera at +y)
"""
from __future__ import annotations

import math
import pathlib
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Iterable

try:
    import numpy as np
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon
    from matplotlib.collections import PatchCollection
except ImportError as e:
    sys.exit(
        f"[preview-gdml] missing dep: {e}. "
        "Run this through /geant4-claude:geant4-preview, which uses the "
        "plugin-managed venv. If deps are still missing, re-launch Claude "
        "Code to fire the SessionStart hook (it seeds the managed venv "
        "automatically). Do not pip install --user (pollutes host "
        "site-packages)."
    )


# Unit parsing --------------------------------------------------------------

_LENGTH_UNITS = {
    "m": 1000.0, "cm": 10.0, "mm": 1.0, "um": 1e-3, "nm": 1e-6,
}
_ANGLE_UNITS = {"rad": 1.0, "deg": math.pi / 180.0, "radian": 1.0, "degree": math.pi / 180.0}


def _length_mm(value: str, unit: str | None) -> float:
    """Convert a length string + unit suffix into millimetres."""
    if value is None:
        return 0.0
    return float(value) * _LENGTH_UNITS.get((unit or "mm"), 1.0)


def _angle_rad(value: str, unit: str | None) -> float:
    if value is None:
        return 0.0
    return float(value) * _ANGLE_UNITS.get((unit or "rad"), 1.0)


# Data model ----------------------------------------------------------------


@dataclass
class Placement:
    """A solid placed in world coordinates."""
    name: str
    solid_type: str
    points: np.ndarray  # (N, 3) point cloud sampling the solid's boundary in world frame


@dataclass
class Solid:
    kind: str
    params: dict  # all geometric params in mm / radians


# GDML parsing --------------------------------------------------------------


def _drop_ns(tag: str) -> str:
    """Strip any XML namespace prefix from a tag name."""
    return tag.split("}", 1)[-1] if "}" in tag else tag


def _find_child(parent: ET.Element, name: str) -> ET.Element | None:
    for c in parent:
        if _drop_ns(c.tag) == name:
            return c
    return None


def _iter_children(parent: ET.Element, name: str) -> Iterable[ET.Element]:
    for c in parent:
        if _drop_ns(c.tag) == name:
            yield c


def parse_defines(root: ET.Element) -> tuple[dict, dict]:
    """Return (positions, rotations) maps keyed by name. Values are 3-tuples
    in mm / radians."""
    positions: dict[str, tuple[float, float, float]] = {}
    rotations: dict[str, tuple[float, float, float]] = {}
    define = _find_child(root, "define")
    if define is None:
        return positions, rotations
    for c in define:
        tag = _drop_ns(c.tag)
        if tag == "position":
            unit = c.get("unit") or c.get("lunit")
            positions[c.get("name", "")] = (
                _length_mm(c.get("x", "0"), unit),
                _length_mm(c.get("y", "0"), unit),
                _length_mm(c.get("z", "0"), unit),
            )
        elif tag == "rotation":
            unit = c.get("unit") or c.get("aunit")
            rotations[c.get("name", "")] = (
                _angle_rad(c.get("x", "0"), unit),
                _angle_rad(c.get("y", "0"), unit),
                _angle_rad(c.get("z", "0"), unit),
            )
    return positions, rotations


def parse_solids(root: ET.Element) -> dict[str, Solid]:
    solids: dict[str, Solid] = {}
    solids_el = _find_child(root, "solids")
    if solids_el is None:
        return solids
    for el in solids_el:
        tag = _drop_ns(el.tag)
        name = el.get("name", "")
        lunit = el.get("lunit") or "mm"
        aunit = el.get("aunit") or "deg"
        if tag == "box":
            solids[name] = Solid("box", {
                "x": _length_mm(el.get("x", "0"), lunit),
                "y": _length_mm(el.get("y", "0"), lunit),
                "z": _length_mm(el.get("z", "0"), lunit),
            })
        elif tag == "tube":
            solids[name] = Solid("tube", {
                "rmin": _length_mm(el.get("rmin", "0"), lunit),
                "rmax": _length_mm(el.get("rmax", "0"), lunit),
                "z":    _length_mm(el.get("z", "0"), lunit),
                "startphi": _angle_rad(el.get("startphi", "0"), aunit),
                "deltaphi": _angle_rad(el.get("deltaphi", "360"), aunit),
            })
        elif tag == "cone":
            solids[name] = Solid("cone", {
                "rmin1": _length_mm(el.get("rmin1", "0"), lunit),
                "rmax1": _length_mm(el.get("rmax1", "0"), lunit),
                "rmin2": _length_mm(el.get("rmin2", "0"), lunit),
                "rmax2": _length_mm(el.get("rmax2", "0"), lunit),
                "z":     _length_mm(el.get("z", "0"), lunit),
                "startphi": _angle_rad(el.get("startphi", "0"), aunit),
                "deltaphi": _angle_rad(el.get("deltaphi", "360"), aunit),
            })
        elif tag == "polycone":
            zplanes = []
            for zp in _iter_children(el, "zplane"):
                zplanes.append({
                    "rmin": _length_mm(zp.get("rmin", "0"), lunit),
                    "rmax": _length_mm(zp.get("rmax", "0"), lunit),
                    "z":    _length_mm(zp.get("z", "0"), lunit),
                })
            solids[name] = Solid("polycone", {
                "zplanes": zplanes,
                "startphi": _angle_rad(el.get("startphi", "0"), aunit),
                "deltaphi": _angle_rad(el.get("deltaphi", "360"), aunit),
            })
        else:
            # Unsupported — render as the GDML-declared bounding aux if any,
            # or just a tiny placeholder so the user sees something.
            solids[name] = Solid("unsupported", {"orig": tag})
    return solids


@dataclass
class Volume:
    name: str
    solidref: str
    daughters: list[dict] = field(default_factory=list)


def parse_structure(root: ET.Element) -> tuple[dict[str, Volume], str | None]:
    volumes: dict[str, Volume] = {}
    structure = _find_child(root, "structure")
    if structure is None:
        return volumes, None
    for v in _iter_children(structure, "volume"):
        name = v.get("name", "")
        solidref_el = _find_child(v, "solidref")
        solidref = solidref_el.get("ref", "") if solidref_el is not None else ""
        vol = Volume(name=name, solidref=solidref)
        for child in _iter_children(v, "physvol"):
            volref_el = _find_child(child, "volumeref")
            pos_inline = _find_child(child, "position")
            pos_ref_el = _find_child(child, "positionref")
            rot_inline = _find_child(child, "rotation")
            rot_ref_el = _find_child(child, "rotationref")
            vol.daughters.append({
                "name": child.get("name", ""),
                "volumeref": volref_el.get("ref", "") if volref_el is not None else "",
                "position_inline": pos_inline,
                "position_ref": pos_ref_el.get("ref", "") if pos_ref_el is not None else None,
                "rotation_inline": rot_inline,
                "rotation_ref": rot_ref_el.get("ref", "") if rot_ref_el is not None else None,
            })
        volumes[name] = vol

    # World volume: <setup>/<world ref="..."/>. If missing, fall back to
    # the volume that isn't referenced as a daughter anywhere.
    world_name = None
    setup = _find_child(root, "setup")
    if setup is not None:
        world_el = _find_child(setup, "world")
        if world_el is not None:
            world_name = world_el.get("ref")
    if world_name is None and volumes:
        referenced = {d["volumeref"] for v in volumes.values() for d in v.daughters}
        roots = [n for n in volumes if n not in referenced]
        if roots:
            world_name = roots[0]
    return volumes, world_name


def _resolve_transform(
    daughter: dict,
    positions: dict, rotations: dict,
) -> tuple[np.ndarray, np.ndarray]:
    """Return (translation, rotation_matrix) for a physvol."""
    t = np.zeros(3)
    if daughter["position_inline"] is not None:
        pe = daughter["position_inline"]
        unit = pe.get("unit") or pe.get("lunit")
        t = np.array([
            _length_mm(pe.get("x", "0"), unit),
            _length_mm(pe.get("y", "0"), unit),
            _length_mm(pe.get("z", "0"), unit),
        ])
    elif daughter["position_ref"]:
        t = np.array(positions.get(daughter["position_ref"], (0.0, 0.0, 0.0)))

    rot_xyz = (0.0, 0.0, 0.0)
    if daughter["rotation_inline"] is not None:
        re = daughter["rotation_inline"]
        unit = re.get("unit") or re.get("aunit")
        rot_xyz = (
            _angle_rad(re.get("x", "0"), unit),
            _angle_rad(re.get("y", "0"), unit),
            _angle_rad(re.get("z", "0"), unit),
        )
    elif daughter["rotation_ref"]:
        rot_xyz = rotations.get(daughter["rotation_ref"], (0.0, 0.0, 0.0))
    R = _rotation_matrix(*rot_xyz)
    return t, R


def _rotation_matrix(rx: float, ry: float, rz: float) -> np.ndarray:
    """Geant4 GDML convention: extrinsic X-Y-Z (R = Rz * Ry * Rx)."""
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


# Solid → boundary point cloud ---------------------------------------------

_AZ_SAMPLES = 32


def _box_points(p: dict) -> np.ndarray:
    hx, hy, hz = p["x"] / 2, p["y"] / 2, p["z"] / 2
    return np.array([
        [sx * hx, sy * hy, sz * hz]
        for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)
    ])


def _tube_points(p: dict) -> np.ndarray:
    phi0, dphi = p["startphi"], p["deltaphi"]
    phis = np.linspace(phi0, phi0 + dphi, _AZ_SAMPLES, endpoint=(dphi < 2 * math.pi - 1e-9))
    rmin, rmax, hz = p["rmin"], p["rmax"], p["z"] / 2
    cos_p, sin_p = np.cos(phis), np.sin(phis)
    pts = []
    for r in (rmax,) if rmin == 0 else (rmin, rmax):
        for z in (-hz, hz):
            pts.append(np.stack([r * cos_p, r * sin_p, np.full_like(cos_p, z)], axis=1))
    return np.vstack(pts)


def _cone_points(p: dict) -> np.ndarray:
    phi0, dphi = p["startphi"], p["deltaphi"]
    phis = np.linspace(phi0, phi0 + dphi, _AZ_SAMPLES, endpoint=(dphi < 2 * math.pi - 1e-9))
    cos_p, sin_p = np.cos(phis), np.sin(phis)
    hz = p["z"] / 2
    pts = []
    for r, z in (
        (p["rmin1"], -hz), (p["rmax1"], -hz),
        (p["rmin2"],  hz), (p["rmax2"],  hz),
    ):
        if r <= 0:
            pts.append(np.array([[0.0, 0.0, z]]))
            continue
        pts.append(np.stack([r * cos_p, r * sin_p, np.full_like(cos_p, z)], axis=1))
    return np.vstack(pts)


def _polycone_points(p: dict) -> np.ndarray:
    phi0, dphi = p["startphi"], p["deltaphi"]
    phis = np.linspace(phi0, phi0 + dphi, _AZ_SAMPLES, endpoint=(dphi < 2 * math.pi - 1e-9))
    cos_p, sin_p = np.cos(phis), np.sin(phis)
    pts = []
    for plane in p["zplanes"]:
        z = plane["z"]
        for r in (plane["rmin"], plane["rmax"]):
            if r <= 0:
                pts.append(np.array([[0.0, 0.0, z]]))
                continue
            pts.append(np.stack([r * cos_p, r * sin_p, np.full_like(cos_p, z)], axis=1))
    return np.vstack(pts)


def _unsupported_points(p: dict) -> np.ndarray:
    # 1 mm placeholder cube so unknown solids still appear in the sketch.
    return _box_points({"x": 1.0, "y": 1.0, "z": 1.0})


def _solid_points(solid: Solid) -> np.ndarray:
    if solid.kind == "box":      return _box_points(solid.params)
    if solid.kind == "tube":     return _tube_points(solid.params)
    if solid.kind == "cone":     return _cone_points(solid.params)
    if solid.kind == "polycone": return _polycone_points(solid.params)
    return _unsupported_points(solid.params)


# Tree flattening -----------------------------------------------------------


def _flatten(
    vol_name: str,
    parent_R: np.ndarray, parent_t: np.ndarray,
    volumes: dict[str, Volume],
    solids: dict[str, Solid],
    positions: dict, rotations: dict,
    out: list[Placement],
    depth: int = 0,
    is_root: bool = False,
):
    if depth > 20:
        return
    vol = volumes.get(vol_name)
    if vol is None:
        return
    solid = solids.get(vol.solidref)
    if solid is None:
        return
    raw_pts = _solid_points(solid)
    world_pts = (parent_R @ raw_pts.T).T + parent_t
    # Suppress the world volume itself — it usually swamps the active
    # geometry. Daughters that reference its volume name will still draw.
    if not is_root:
        out.append(Placement(name=vol.name, solid_type=solid.kind, points=world_pts))
    for d in vol.daughters:
        dt, dR = _resolve_transform(d, positions, rotations)
        child_R = parent_R @ dR
        child_t = parent_R @ dt + parent_t
        _flatten(
            d["volumeref"], child_R, child_t,
            volumes, solids, positions, rotations,
            out, depth + 1, is_root=False,
        )


# Projection + 2D convex hull ----------------------------------------------


def _project(pts: np.ndarray, view: str) -> np.ndarray:
    """Drop one axis to get a 2D point cloud."""
    if view == "xy":  return pts[:, [0, 1]]
    if view == "yz":  return pts[:, [1, 2]]
    if view == "xz":  return pts[:, [0, 2]]
    raise ValueError(view)


def _convex_hull_2d(pts: np.ndarray) -> np.ndarray:
    """Andrew's monotone chain; returns a closed polygon (n+1, 2) with the
    first point repeated at the end."""
    if len(pts) < 3:
        return pts
    # Deduplicate and sort lexicographically.
    pts = np.unique(np.round(pts, 6), axis=0)
    pts = pts[np.lexsort((pts[:, 1], pts[:, 0]))]

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    upper = []
    for p in pts[::-1]:
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    hull = np.array(lower[:-1] + upper[:-1] + [lower[0]])
    return hull


# Rendering -----------------------------------------------------------------


_VIEW_LABELS = {
    "xy": ("end view (camera at +z)", "x [mm]", "y [mm]"),
    "yz": ("side view (camera at +x)", "y [mm]", "z [mm]"),
    "xz": ("top view (camera at +y)",  "x [mm]", "z [mm]"),
}

_KIND_COLOR = {
    "box":         "#3182ce",
    "tube":        "#38a169",
    "cone":        "#dd6b20",
    "polycone":    "#805ad5",
    "unsupported": "#a0aec0",
}


def render(placements: list[Placement], gdml_path: pathlib.Path, view: str, out_path: pathlib.Path):
    title, xlabel, ylabel = _VIEW_LABELS[view]
    fig, ax = plt.subplots(figsize=(8, 6), dpi=120)
    patches = []
    colors = []
    edge_colors = []
    annotations = []  # (x, y, "!") for unsupported solids

    for pl in placements:
        proj = _project(pl.points, view)
        hull = _convex_hull_2d(proj)
        if len(hull) < 3:
            continue
        patches.append(Polygon(hull, closed=True))
        colors.append(_KIND_COLOR.get(pl.solid_type, "#666"))
        edge_colors.append("#1a202c")
        if pl.solid_type == "unsupported":
            cx, cy = hull[:, 0].mean(), hull[:, 1].mean()
            annotations.append((cx, cy, "!"))

    if patches:
        coll = PatchCollection(
            patches, facecolor=colors, edgecolor=edge_colors,
            linewidths=0.8, alpha=0.55,
        )
        ax.add_collection(coll)

    for x, y, sym in annotations:
        ax.text(x, y, sym, ha="center", va="center", color="#c53030",
                fontsize=14, fontweight="bold")

    ax.set_aspect("equal", "box")
    ax.autoscale_view()
    ax.grid(True, linestyle="--", linewidth=0.4, color="#cbd5e0", alpha=0.6)
    ax.axhline(0, color="#a0aec0", linewidth=0.5)
    ax.axvline(0, color="#a0aec0", linewidth=0.5)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(f"{title}\n{gdml_path.name}", fontsize=11)

    # Legend.
    used = {p.solid_type for p in placements}
    handles = [
        plt.Rectangle((0, 0), 1, 1, facecolor=_KIND_COLOR[k], edgecolor="#1a202c",
                      linewidth=0.8, alpha=0.55, label=k)
        for k in ("box", "tube", "cone", "polycone", "unsupported") if k in used
    ]
    if handles:
        ax.legend(handles=handles, loc="upper right", fontsize=8, framealpha=0.85)

    fig.tight_layout()
    fig.savefig(out_path)
    plt.close(fig)


# Main ----------------------------------------------------------------------


def main(argv=None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    if len(argv) != 2:
        print(__doc__.strip().split("\n\n")[0], file=sys.stderr)
        print(f"\nusage: {sys.argv[0]} <input.gdml> <out_dir>", file=sys.stderr)
        return 2

    gdml_path = pathlib.Path(argv[0]).resolve()
    out_dir = pathlib.Path(argv[1]).resolve()
    if not gdml_path.is_file():
        print(f"[preview-gdml] no such file: {gdml_path}", file=sys.stderr)
        return 2
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        tree = ET.parse(gdml_path)
    except ET.ParseError as e:
        print(f"[preview-gdml] GDML parse error: {e}", file=sys.stderr)
        return 1
    root = tree.getroot()

    positions, rotations = parse_defines(root)
    solids = parse_solids(root)
    volumes, world_name = parse_structure(root)
    if world_name is None:
        print("[preview-gdml] no world volume found in <setup> / <structure>",
              file=sys.stderr)
        return 1

    placements: list[Placement] = []
    _flatten(
        world_name, np.eye(3), np.zeros(3),
        volumes, solids, positions, rotations,
        placements, depth=0, is_root=True,
    )
    if not placements:
        print("[preview-gdml] no daughter volumes to draw — only the world "
              "exists. Re-check the GDML <structure>.", file=sys.stderr)
        return 1

    kind_counts = {}
    for pl in placements:
        kind_counts[pl.solid_type] = kind_counts.get(pl.solid_type, 0) + 1
    summary = ", ".join(f"{n} {k}" for k, n in sorted(kind_counts.items()))
    print(f"[preview-gdml] drawing {len(placements)} placement(s): {summary}")

    for view in ("xy", "yz", "xz"):
        out_path = out_dir / f"preview_{view}.png"
        render(placements, gdml_path, view, out_path)
        print(f"  wrote {out_path}")

    if "unsupported" in kind_counts:
        print(f"[preview-gdml] note: {kind_counts['unsupported']} unsupported "
              "solid(s) drawn as bounding boxes with '!' badges. "
              "For full rendering, try --backend=raytracer.",
              file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
