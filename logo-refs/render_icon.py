#!/usr/bin/env python3
"""Render Baseline app icon as a 1024x1024 PNG using only stdlib."""

import struct
import zlib
import math
import sys

def create_png(width, height, pixels):
    """Create PNG from RGBA pixel array."""
    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter: none
        for x in range(width):
            idx = (y * width + x) * 4
            raw += bytes(pixels[idx:idx+4])

    header = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    idat = chunk(b'IDAT', zlib.compress(raw, 9))
    iend = chunk(b'IEND', b'')
    return header + ihdr + idat + iend


def lerp(a, b, t):
    return a + (b - a) * t


def draw_line_aa(pixels, w, h, x0, y0, x1, y1, thickness, r, g, b, alpha):
    """Draw an anti-aliased thick line segment."""
    dx = x1 - x0
    dy = y1 - y0
    length = math.sqrt(dx*dx + dy*dy)
    if length < 0.001:
        return

    # Normal to the line
    nx = -dy / length
    ny = dx / length

    # Bounding box with padding
    pad = thickness + 2
    min_x = max(0, int(min(x0, x1) - pad))
    max_x = min(w - 1, int(max(x0, x1) + pad))
    min_y = max(0, int(min(y0, y1) - pad))
    max_y = min(h - 1, int(max(y0, y1) + pad))

    half = thickness / 2.0

    for py in range(min_y, max_y + 1):
        for px in range(min_x, max_x + 1):
            # Project point onto line
            apx = px - x0
            apy = py - y0
            t = (apx * dx + apy * dy) / (length * length)

            # Distance along line (clamped to segment)
            t_clamped = max(0, min(1, t))
            closest_x = x0 + t_clamped * dx
            closest_y = y0 + t_clamped * dy

            dist = math.sqrt((px - closest_x)**2 + (py - closest_y)**2)

            if dist < half + 1:
                # Anti-aliasing at edges
                coverage = max(0, min(1, half + 0.5 - dist))
                a_final = alpha * coverage

                if a_final > 0.003:
                    idx = (py * w + px) * 4
                    # Alpha composite over existing
                    existing_r = pixels[idx]
                    existing_g = pixels[idx+1]
                    existing_b = pixels[idx+2]
                    existing_a = pixels[idx+3] / 255.0

                    out_a = a_final + existing_a * (1 - a_final)
                    if out_a > 0:
                        out_r = int((r * a_final + existing_r * existing_a * (1 - a_final)) / out_a)
                        out_g = int((g * a_final + existing_g * existing_a * (1 - a_final)) / out_a)
                        out_b = int((b * a_final + existing_b * existing_a * (1 - a_final)) / out_a)
                        pixels[idx] = min(255, out_r)
                        pixels[idx+1] = min(255, out_g)
                        pixels[idx+2] = min(255, out_b)
                        pixels[idx+3] = min(255, int(out_a * 255))


def draw_polyline(pixels, w, h, points, thickness, r, g, b, alpha):
    """Draw connected line segments with round joins."""
    for i in range(len(points) - 1):
        draw_line_aa(pixels, w, h,
                     points[i][0], points[i][1],
                     points[i+1][0], points[i+1][1],
                     thickness, r, g, b, alpha)


def apex_path(w, h, base_y, peak_h, peak_w):
    cx = w / 2
    return [
        (w * 0.06, base_y),
        (cx - peak_w, base_y),
        (cx, base_y - peak_h),
        (cx + peak_w, base_y),
        (w * 0.94, base_y),
    ]


def ekg_path(w, h, base_y):
    sx = w * 0.06
    ex = w * 0.94
    r = ex - sx
    return [
        (sx, base_y),
        (sx + r * 0.18, base_y),
        (sx + r * 0.24, base_y),
        (sx + r * 0.34, base_y - h * 0.28),
        (sx + r * 0.48, base_y + h * 0.25),
        (sx + r * 0.60, base_y - h * 0.14),
        (sx + r * 0.70, base_y),
        (sx + r * 0.76, base_y),
        (ex, base_y),
    ]


def fill_under_ekg(pixels, w, h, pts, fill_bottom, fr, fg, fb, top_alpha, bot_alpha):
    """Fill area under EKG path with vertical gradient."""
    # Find bounding box
    min_y = int(min(p[1] for p in pts))
    max_y = int(fill_bottom)

    for py in range(max(0, min_y), min(h, max_y + 1)):
        # Find x range at this y by scanning left/right edges of the polygon
        # The polygon is: pts path on top, then straight line at fill_bottom
        # For each scanline, find where it intersects the path segments

        # Build closed polygon: path + bottom edge
        poly = list(pts) + [(pts[-1][0], fill_bottom), (pts[0][0], fill_bottom)]

        intersections = []
        for i in range(len(poly)):
            x0, y0 = poly[i]
            x1, y1 = poly[(i + 1) % len(poly)]
            if (y0 <= py < y1) or (y1 <= py < y0):
                if abs(y1 - y0) > 0.001:
                    t = (py - y0) / (y1 - y0)
                    ix = x0 + t * (x1 - x0)
                    intersections.append(ix)

        intersections.sort()

        # Alpha gradient based on y position
        if max_y > min_y:
            t = (py - min_y) / (max_y - min_y)
            alpha = top_alpha + (bot_alpha - top_alpha) * t
        else:
            alpha = top_alpha

        if alpha < 0.005:
            continue

        # Fill between pairs of intersections
        for j in range(0, len(intersections) - 1, 2):
            x_start = max(0, int(intersections[j]))
            x_end = min(w - 1, int(intersections[j + 1]))
            for px in range(x_start, x_end + 1):
                idx = (py * w + px) * 4
                existing_r = pixels[idx]
                existing_g = pixels[idx + 1]
                existing_b = pixels[idx + 2]
                existing_a = pixels[idx + 3] / 255.0

                out_a = alpha + existing_a * (1 - alpha)
                if out_a > 0:
                    out_r = int((fr * alpha + existing_r * existing_a * (1 - alpha)) / out_a)
                    out_g = int((fg * alpha + existing_g * existing_a * (1 - alpha)) / out_a)
                    out_b = int((fb * alpha + existing_b * existing_a * (1 - alpha)) / out_a)
                    pixels[idx] = min(255, out_r)
                    pixels[idx + 1] = min(255, out_g)
                    pixels[idx + 2] = min(255, out_b)
                    pixels[idx + 3] = min(255, int(out_a * 255))


def render_ekg_icon(output_path, size=1024, bg=(0x1A, 0x1A, 0x1E), color=(255, 255, 255),
                    area_fill=True, fill_color=(107, 123, 148), fill_top_alpha=0.40, fill_bot_alpha=0.04):
    w = h = size
    pixels = bytearray(w * h * 4)

    for i in range(w * h):
        pixels[i*4] = bg[0]
        pixels[i*4+1] = bg[1]
        pixels[i*4+2] = bg[2]
        pixels[i*4+3] = 255

    lw = size * 0.028
    base_y = h * 0.50
    pts = ekg_path(w, h, base_y)
    fill_bottom = h * 0.82

    # Area fill under the EKG
    if area_fill:
        fr, fg, fb = fill_color
        fill_under_ekg(pixels, w, h, pts, fill_bottom, fr, fg, fb, fill_top_alpha, fill_bot_alpha)

    # Stroke
    cr, cg, cb = color
    draw_polyline(pixels, w, h, pts, lw, cr, cg, cb, 1.0)

    png_data = create_png(w, h, pixels)
    with open(output_path, 'wb') as f:
        f.write(png_data)
    print(f"Wrote {output_path} ({w}x{h})")


def render_apex_icon(output_path, size=1024, bg=(0, 0, 0), color=(255, 255, 255),
                     blue_line=-1, blue_color=(107, 123, 148)):
    w = h = size
    pixels = bytearray(w * h * 4)

    # Fill background
    for i in range(w * h):
        pixels[i*4] = bg[0]
        pixels[i*4+1] = bg[1]
        pixels[i*4+2] = bg[2]
        pixels[i*4+3] = 255

    gap = size * 0.045
    lw = size * 0.022
    peak_h = h * 0.34
    peak_w = w * 0.16
    base_y = h * 0.56
    alphas = [1.0, 0.5, 0.25]

    for i in range(3):
        pts = apex_path(w, h, base_y + i * gap, peak_h, peak_w)
        if i == blue_line:
            cr, cg, cb = blue_color
        else:
            cr, cg, cb = color
        draw_polyline(pixels, w, h, pts, lw, cr, cg, cb, alphas[i])

    png_data = create_png(w, h, pixels)
    with open(output_path, 'wb') as f:
        f.write(png_data)
    print(f"Wrote {output_path} ({w}x{h})")


if __name__ == '__main__':
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '/Users/ben/projects/baseline/Baseline/Assets.xcassets/AppIcon.appiconset'
    # Option 5 from R8b: blue area fill on app background
    render_ekg_icon(f'{out_dir}/AppIcon.png', size=1024)
    print("Done!")
