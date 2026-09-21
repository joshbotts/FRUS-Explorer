#!/usr/bin/env python3
"""Ink inside a rect of one rendered frame, by the preflight's own modal-luma rule.

A separate file rather than a heredoc, because the caller needs it inside a command substitution and
a heredoc there is a delimiter collision waiting to happen. Args: <frame.png> <x> <y> <w> <h>.
"""
import subprocess, sys, numpy as np

path, x, y, w, h = sys.argv[1], *map(int, sys.argv[2:6])
raw = subprocess.run(["ffmpeg", "-hide_banner", "-v", "error", "-i", path,
                      "-pix_fmt", "gray", "-f", "rawvideo", "-"],
                     stdout=subprocess.PIPE, check=True).stdout
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                        "-show_entries", "stream=width,height", "-of", "csv=p=0", path],
                       stdout=subprocess.PIPE, text=True, check=True).stdout.strip().split(",")
W, H = int(probe[0]), int(probe[1])
a = np.frombuffer(raw, dtype=np.uint8).reshape(H, W)
mask = a > np.bincount(a.ravel()).argmax() + 4
print(int(mask[max(0, y):y + h, max(0, x):x + w].sum()))
