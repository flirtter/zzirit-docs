#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def is_selection_blue(r: int, g: int, b: int, a: int) -> bool:
    if a < 180:
        return False
    return b >= 220 and 90 <= g <= 210 and r <= 90


def is_footer_blue(r: int, g: int, b: int, a: int) -> bool:
    if a < 180:
        return False
    return b >= 170 and 90 <= g <= 220 and r <= 80


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Crop the selected Figma node from a screenshot by detecting the blue selection outline.",
    )
    parser.add_argument("input_image")
    parser.add_argument("output_image")
    parser.add_argument("--padding", type=int, default=8)
    parser.add_argument("--min-width", type=int, default=180)
    parser.add_argument("--min-height", type=int, default=180)
    parser.add_argument("--trim-footer", action="store_true", default=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path = Path(args.input_image)
    output_path = Path(args.output_image)
    image = Image.open(input_path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    visited = [[False] * width for _ in range(height)]

    best = None
    best_score = -1

    for y in range(height):
        for x in range(width):
            if visited[y][x]:
                continue
            visited[y][x] = True
            r, g, b, a = pixels[x, y]
            if not is_selection_blue(r, g, b, a):
                continue

            queue = deque([(x, y)])
            count = 0
            min_x = max_x = x
            min_y = max_y = y

            while queue:
                cx, cy = queue.popleft()
                count += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)

                for nx, ny in (
                    (cx - 1, cy),
                    (cx + 1, cy),
                    (cx, cy - 1),
                    (cx, cy + 1),
                    (cx - 1, cy - 1),
                    (cx + 1, cy - 1),
                    (cx - 1, cy + 1),
                    (cx + 1, cy + 1),
                ):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height or visited[ny][nx]:
                        continue
                    visited[ny][nx] = True
                    nr, ng, nb, na = pixels[nx, ny]
                    if is_selection_blue(nr, ng, nb, na):
                        queue.append((nx, ny))

            box_w = max_x - min_x + 1
            box_h = max_y - min_y + 1
            if box_w < args.min_width or box_h < args.min_height:
                continue

            score = count + (box_w * box_h) / 50
            if score > best_score:
                best_score = score
                best = (min_x, min_y, max_x, max_y, count)

    if best is None:
        raise SystemExit("Could not detect a sufficiently large blue selection outline.")

    min_x, min_y, max_x, max_y, count = best
    crop_left = max(min_x + args.padding, 0)
    crop_top = max(min_y + args.padding, 0)
    crop_right = min(max_x - args.padding, width)
    crop_bottom = min(max_y - args.padding, height)

    if crop_right <= crop_left or crop_bottom <= crop_top:
        raise SystemExit("Detected selection outline but crop bounds were invalid.")

    cropped = image.crop((crop_left, crop_top, crop_right, crop_bottom))
    if args.trim_footer:
      cropped_pixels = cropped.load()
      cropped_w, cropped_h = cropped.size
      footer_cut = None
      scan_start = int(cropped_h * 0.55)
      for y in range(cropped_h - 1, scan_start, -1):
          blue_count = 0
          for x in range(cropped_w):
              if is_footer_blue(*cropped_pixels[x, y]):
                  blue_count += 1
          if blue_count >= int(cropped_w * 0.28):
              footer_cut = y
      if footer_cut is not None and footer_cut > int(cropped_h * 0.65):
          cropped = cropped.crop((0, 0, cropped_w, max(footer_cut - 2, 1)))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    cropped.save(output_path)

    print(
        {
            "input": str(input_path),
            "output": str(output_path),
            "selection_bbox": [min_x, min_y, max_x, max_y],
            "crop_bbox": [crop_left, crop_top, crop_right, crop_bottom],
            "blue_pixels": count,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
