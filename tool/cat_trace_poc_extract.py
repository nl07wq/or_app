"""Deterministic development-only CAT silhouette trace extractor.

Usage:
  python tool/cat_trace_poc_extract.py <source.jpg>

It deliberately prints generated Dart data instead of writing repository source.
The checked-in vector data is reviewed separately. No raster is retained.
"""

from __future__ import annotations

import json
import math
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

THRESHOLD = 128
OPENING_RADIUS = 1
TOLERANCES = {"high": 1.5, "medium": 4.0, "low": 9.0}
CATMULL_SAMPLES = 12


def erode(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, OPENING_RADIUS, constant_values=False)
    rows, cols = mask.shape
    result = np.ones_like(mask)
    for dy in range(OPENING_RADIUS * 2 + 1):
        for dx in range(OPENING_RADIUS * 2 + 1):
            result &= padded[dy : dy + rows, dx : dx + cols]
    return result


def dilate(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, OPENING_RADIUS, constant_values=False)
    rows, cols = mask.shape
    result = np.zeros_like(mask)
    for dy in range(OPENING_RADIUS * 2 + 1):
        for dx in range(OPENING_RADIUS * 2 + 1):
            result |= padded[dy : dy + rows, dx : dx + cols]
    return result


def largest_component(mask: np.ndarray) -> np.ndarray:
    rows, cols = mask.shape
    seen = np.zeros_like(mask)
    largest: list[tuple[int, int]] = []
    for y in range(rows):
        for x in range(cols):
            if not mask[y, x] or seen[y, x]:
                continue
            queue = deque([(y, x)])
            seen[y, x] = True
            component: list[tuple[int, int]] = []
            while queue:
                cy, cx = queue.popleft()
                component.append((cy, cx))
                for ny in range(max(0, cy - 1), min(rows, cy + 2)):
                    for nx in range(max(0, cx - 1), min(cols, cx + 2)):
                        if mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            queue.append((ny, nx))
            if len(component) > len(largest):
                largest = component
    output = np.zeros_like(mask)
    for y, x in largest:
        output[y, x] = True
    return output


def outer_contour(mask: np.ndarray) -> list[tuple[float, float]]:
    """Build oriented grid boundary loops, then return the largest outer loop."""
    rows, cols = mask.shape
    edges: dict[tuple[int, int], tuple[int, int]] = {}
    for y in range(rows):
        for x in range(cols):
            if not mask[y, x]:
                continue
            if y == 0 or not mask[y - 1, x]:
                edges[(x, y)] = (x + 1, y)
            if x == cols - 1 or not mask[y, x + 1]:
                edges[(x + 1, y)] = (x + 1, y + 1)
            if y == rows - 1 or not mask[y + 1, x]:
                edges[(x + 1, y + 1)] = (x, y + 1)
            if x == 0 or not mask[y, x - 1]:
                edges[(x, y + 1)] = (x, y)
    loops: list[list[tuple[float, float]]] = []
    while edges:
        start = next(iter(edges))
        point = start
        loop = [point]
        while True:
            point = edges.pop(point)
            if point == start:
                break
            loop.append(point)
        loops.append(loop)
    def area(loop: list[tuple[float, float]]) -> float:
        return abs(sum(
            x1 * y2 - x2 * y1
            for (x1, y1), (x2, y2) in zip(loop, loop[1:] + loop[:1])
        )) / 2
    return max(loops, key=area)


def distance(point, start, end) -> float:
    dx, dy = end[0] - start[0], end[1] - start[1]
    if dx == 0 and dy == 0:
        return math.dist(point, start)
    return abs(dy * point[0] - dx * point[1] + end[0] * start[1] - end[1] * start[0]) / math.hypot(dx, dy)


def rdp(points: list[tuple[float, float]], tolerance: float) -> list[tuple[float, float]]:
    if len(points) < 3:
        return points
    start, end = points[0], points[-1]
    index, maximum = max(
        ((index, distance(point, start, end)) for index, point in enumerate(points[1:-1], 1)),
        key=lambda item: item[1],
        default=(0, 0),
    )
    if maximum <= tolerance:
        return [start, end]
    return rdp(points[: index + 1], tolerance)[:-1] + rdp(points[index:], tolerance)


def simplify_closed(points: list[tuple[float, float]], tolerance: float) -> list[tuple[float, float]]:
    anchor = min(range(len(points)), key=lambda index: (points[index][0], points[index][1]))
    rotated = points[anchor:] + points[:anchor]
    midpoint = len(rotated) // 2
    first = rdp(rotated[: midpoint + 1], tolerance)
    second = rdp(rotated[midpoint:] + [rotated[0]], tolerance)
    return first[:-1] + second[:-1]


def catmull_rom(points: list[tuple[float, float]], samples: int) -> list[tuple[float, float]]:
    output: list[tuple[float, float]] = []
    count = len(points)
    for index in range(count):
        p0, p1, p2, p3 = (points[(index + offset) % count] for offset in (-1, 0, 1, 2))
        for sample in range(samples):
            t = sample / samples
            t2, t3 = t * t, t * t * t
            x = .5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2*p0[0] - 5*p1[0] + 4*p2[0] - p3[0]) * t2 + (-p0[0] + 3*p1[0] - 3*p2[0] + p3[0]) * t3)
            y = .5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2*p0[1] - 5*p1[1] + 4*p2[1] - p3[1]) * t2 + (-p0[1] + 3*p1[1] - 3*p2[1] + p3[1]) * t3)
            output.append((x, y))
    return output


def raster_iou(mask: np.ndarray, outline: list[tuple[float, float]]) -> tuple[float, float]:
    image = Image.new("1", (mask.shape[1], mask.shape[0]), 0)
    ImageDraw.Draw(image).polygon(outline, fill=1)
    rendered = np.array(image, dtype=bool)
    union = np.logical_or(mask, rendered).sum()
    intersection = np.logical_and(mask, rendered).sum()
    disagreement = np.logical_xor(mask, rendered).sum() / union
    return intersection / union, disagreement


def normalized(points, width, height):
    xs, ys = zip(*points)
    min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
    scale = 1 / max(max_x - min_x, max_y - min_y)
    return [((x - min_x) * scale, (y - min_y) * scale) for x, y in points]


def dart_points(points) -> str:
    return ",\n    ".join(
        f"Offset({x:.6f}, {y:.6f})" for x, y in points
    )


def dart_output(report) -> str:
    levels = report["levels"]
    blocks = []
    for name in ("high", "medium", "low"):
        level = levels[name]
        blocks.append(
            f"""  CatTraceVectorLevel(
    name: '{name.upper()}',
    tolerance: {level['tolerance']},
    sourcePointCount: {level['pointCount']},
    iou: {level['iou']},
    disagreement: {level['disagreement']},
    points: [
    {dart_points(level['points'])},
    ],
  ),"""
        )
    return (
        "part of 'cat_trace_poc_data.dart';\n\n"
        "// Generated by tool/cat_trace_poc_extract.py; do not hand-edit.\n"
        "const generatedCatTraceVectorLevels = <CatTraceVectorLevel>[\n"
        + "\n".join(blocks)
        + "\n];"
    )


def main(path: str, dart: bool = False) -> None:
    image = Image.open(path).convert("L")
    source = np.array(image)
    mask = source < THRESHOLD
    mask = dilate(erode(mask))
    mask = largest_component(mask)
    raw = outer_contour(mask)
    report = {
        "source": {"width": image.width, "height": image.height},
        "threshold": THRESHOLD,
        "openingRadius": OPENING_RADIUS,
        "rawPointCount": len(raw),
        "levels": {},
    }
    for name, tolerance in TOLERANCES.items():
        simplified = simplify_closed(raw, tolerance)
        fitted = catmull_rom(simplified, CATMULL_SAMPLES)
        iou, disagreement = raster_iou(mask, fitted)
        report["levels"][name] = {
            "tolerance": tolerance,
            "pointCount": len(simplified),
            "iou": round(iou, 6),
            "disagreement": round(disagreement, 6),
            "points": [[round(x, 6), round(y, 6)] for x, y in normalized(simplified, image.width, image.height)],
        }
    print(dart_output(report) if dart else json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv[1], "--dart" in sys.argv[2:])
