# -*- coding: utf-8 -*-
"""渲染 model.glb 一圈 360° 转台 GIF。"""
import io
import math
import os

import numpy as np
import trimesh
import trimesh.transformations as tra
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "output",
                   "triposr_hd" if os.environ.get("HD") else "triposr", "0")
GLB = os.path.join(OUT, "model.glb")
GIF = os.path.join(OUT, "turntable.gif")

data = trimesh.load(GLB)
base = data.to_geometry() if isinstance(data, trimesh.Scene) else data

# 把模型移到原点居中
base.apply_translation(-base.centroid)

N = 60
frames = []
for i in range(N):
    m = base.copy()
    m.apply_transform(tra.rotation_matrix(2 * math.pi * i / N, [0, 1, 0]))
    s = trimesh.Scene(m)
    png = s.save_image(resolution=(640, 640), visible=True)
    frames.append(Image.open(io.BytesIO(png)))
    print(f"frame {i+1}/{N}")

# 优化 GIF：转 RGB + 量化到 256 色并跳过空帧差
frames[0].save(GIF, save_all=True, append_images=frames[1:],
               duration=40, loop=0, disposal=2, optimize=True)
print("GIF saved:", GIF, os.path.getsize(GIF))
