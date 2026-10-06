"""Generate vector-only HIGH data for the ten secondary CAT run sources."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent))
import cat_trace_poc_extract as trace
from PIL import Image
import numpy as np

ROOT = Path(r'C:\Users\Kazuma.H\.codex\codex-remote-attachments\01a0513b-5136-7123-a21b-486c7db62173\C257D204-BD0B-443A-8BB1-0FE047F93505')

def source_index(path):
    return int(path.name.split('pose_')[1].split('_')[0])

def emit(path):
    image = Image.open(path).convert('L')
    mask = trace.largest_component(trace.dilate(trace.erode(np.array(image) < trace.THRESHOLD)))
    raw = trace.outer_contour(mask)
    points = trace.simplify_closed(raw, 1.5)
    iou, disagreement = trace.raster_iou(mask, trace.catmull_rom(points, trace.CATMULL_SAMPLES))
    normalized = trace.normalized(points, image.width, image.height)
    values = ', '.join(f'Offset({x:.6f}, {y:.6f})' for x, y in normalized)
    return f'  CatRunV2Trace({source_index(path)}, {len(raw)}, {len(points)}, {iou:.6f}, {disagreement:.6f}, const [{values}]),'

sources = sorted(ROOT.glob('*.png'), key=source_index)
output = """// Generated mechanically from development-only secondary run sources.\nimport 'package:flutter/material.dart';\n\nclass CatRunV2Trace {\n  const CatRunV2Trace(this.pose, this.rawCount, this.pointCount, this.iou, this.disagreement, this.points);\n  final int pose; final int rawCount; final int pointCount; final double iou; final double disagreement; final List<Offset> points;\n}\n\nfinal catRunV2HighTraces = <CatRunV2Trace>[\n""" + '\n'.join(emit(path) for path in sources) + '\n];\n'
Path('lib/features/system/pages/cat_run_v2_trace_data.dart').write_text(output)
