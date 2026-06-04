#!/usr/bin/env python3
"""Generate Noxy app icons from a programmatically created 1024x1024 source."""
import os
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow")
    exit(1)

def create_source_icon(size=1024):
    """Create a branded Noxy app icon: indigo rounded square with white 'N'."""
    img = Image.new('RGB', (size, size), (99, 102, 241))
    draw = ImageDraw.Draw(img)

    # Indigo color matching the app's accent (#6366F1 approx)
    bg_color = (99, 102, 241)

    # Draw rounded rectangle background
    corner_radius = size // 5
    draw.rounded_rectangle([0, 0, size, size], radius=corner_radius, fill=bg_color)

    # Try to load a font, fallback to default
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size // 2)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", size // 2)
        except:
            font = ImageFont.load_default()

    text = "N"
    # Get text bounding box using textbbox
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (size - text_width) / 2
    y = (size - text_height) / 2 - size // 20  # slight upward adjustment

    draw.text((x, y), text, font=font, fill=(255, 255, 255))

    return img

def generate_all_icons(output_dir: Path):
    source = create_source_icon(1024)

    # All required iOS icon sizes for legacy format
    sizes = [
        (20,   "icon_20pt.png"),
        (40,   "icon_20pt@2x.png"),
        (60,   "icon_20pt@3x.png"),
        (29,   "icon_29pt.png"),
        (58,   "icon_29pt@2x.png"),
        (87,   "icon_29pt@3x.png"),
        (40,   "icon_40pt.png"),
        (80,   "icon_40pt@2x.png"),
        (120,  "icon_40pt@3x.png"),
        (120,  "icon_60pt@2x.png"),
        (180,  "icon_60pt@3x.png"),
        (76,   "icon_76pt.png"),
        (152,  "icon_76pt@2x.png"),
        (167,  "icon_83.5pt@2x.png"),
        (1024, "icon_1024pt.png"),
    ]

    for px, filename in sizes:
        out_path = output_dir / filename
        resized = source.resize((px, px), Image.LANCZOS)
        resized.save(out_path, "PNG")
        print(f"  {filename} -> {px}x{px}")

    print(f"\nDone! Generated {len(sizes)} icons in {output_dir}")

if __name__ == "__main__":
    output = Path("/Users/gorogoro/Dev/Noxy/Noxy/Assets.xcassets/AppIcon.appiconset")
    output.mkdir(parents=True, exist_ok=True)
    generate_all_icons(output)
