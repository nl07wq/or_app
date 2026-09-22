"""Development-only mechanical A/B/C/D medium-vector generator."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent))
import cat_trace_poc_extract as trace
from PIL import Image
import numpy as np

SOURCES = {
    'a': r'C:\Users\Kazuma.H\.codex\codex-remote-attachments\01a0513b-5136-7123-a21b-486c7db62173\217C26B8-520A-459F-BBC3-CB8E530E9B72\4-cat_run_A_isolated_full.png',
    'b': r'C:\Users\Kazuma.H\.codex\codex-remote-attachments\01a0513b-5136-7123-a21b-486c7db62173\217C26B8-520A-459F-BBC3-CB8E530E9B72\3-cat_run_B_isolated_full.png',
    'c': r'C:\Users\Kazuma.H\.codex\codex-remote-attachments\01a0513b-5136-7123-a21b-486c7db62173\217C26B8-520A-459F-BBC3-CB8E530E9B72\2-cat_run_C_isolated_full.png',
    'd': r'C:\Users\Kazuma.H\.codex\codex-remote-attachments\01a0513b-5136-7123-a21b-486c7db62173\217C26B8-520A-459F-BBC3-CB8E530E9B72\1-cat_run_D_isolated_full.png',
}

def pose(name, path):
    image = Image.open(path).convert('L')
    mask = trace.largest_component(trace.dilate(trace.erode(np.array(image) < trace.THRESHOLD)))
    raw = trace.outer_contour(mask)
    points = trace.simplify_closed(raw, 4.0)
    fitted = trace.catmull_rom(points, trace.CATMULL_SAMPLES)
    iou, disagreement = trace.raster_iou(mask, fitted)
    normalized = trace.normalized(points, image.width, image.height)
    dart = ', '.join(f'Offset({x:.6f}, {y:.6f})' for x,y in normalized)
    return f"  CatMultiPoseTrace(CatMultiPose.{name}, {len(raw)}, {len(points)}, {iou:.6f}, {disagreement:.6f}, const [{dart}]),"

out = """// Generated mechanically from development-only A/B/C/D sources.\nimport 'package:flutter/material.dart';\n\nenum CatMultiPose { a, b, c, d }\n\nclass CatMultiPoseTrace {\n  const CatMultiPoseTrace(this.pose, this.rawCount, this.pointCount, this.iou, this.disagreement, this.points);\n  final CatMultiPose pose; final int rawCount; final int pointCount; final double iou; final double disagreement; final List<Offset> points;\n}\n\nfinal catMultiPoseTraces = <CatMultiPoseTrace>[\n""" + "\n".join(pose(n,p) for n,p in SOURCES.items()) + "\n];\n"
Path('lib/features/system/pages/cat_multi_pose_trace_data.dart').write_text(out)
