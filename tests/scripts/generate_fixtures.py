#!/usr/bin/env python3
"""
Generate test fixture images for Zikuli virtual testing.

Creates known patterns at exact pixel dimensions for template matching tests.
"""

import os
from PIL import Image, ImageDraw, ImageFont

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "..", "fixtures", "patterns")

def ensure_dir():
    os.makedirs(FIXTURES_DIR, exist_ok=True)

def create_solid_square(name, size, color):
    """Create a solid color square."""
    img = Image.new("RGBA", (size, size), color + (255,))
    path = os.path.join(FIXTURES_DIR, f"{name}.png")
    img.save(path)
    print(f"Created: {path}")
    return path

def create_button(name, width, height, bg_color, border_color, text=None):
    """Create a button-like pattern."""
    img = Image.new("RGBA", (width, height), bg_color + (255,))
    draw = ImageDraw.Draw(img)

    # Draw border
    draw.rectangle([0, 0, width-1, height-1], outline=border_color + (255,), width=2)

    if text:
        # Try to add text (may fail if no fonts available)
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 12)
        except:
            font = ImageFont.load_default()

        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        x = (width - text_width) // 2
        y = (height - text_height) // 2
        draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)

    path = os.path.join(FIXTURES_DIR, f"{name}.png")
    img.save(path)
    print(f"Created: {path}")
    return path

def create_crosshair(name, size, color):
    """Create a crosshair pattern for precise targeting tests."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))  # Transparent
    draw = ImageDraw.Draw(img)

    center = size // 2

    # Horizontal line
    draw.line([(0, center), (size-1, center)], fill=color + (255,), width=1)
    # Vertical line
    draw.line([(center, 0), (center, size-1)], fill=color + (255,), width=1)
    # Center dot
    draw.ellipse([center-2, center-2, center+2, center+2], fill=color + (255,))

    path = os.path.join(FIXTURES_DIR, f"{name}.png")
    img.save(path)
    print(f"Created: {path}")
    return path

def create_gradient(name, width, height, horizontal=True):
    """Create a gradient pattern for anti-aliasing tests."""
    img = Image.new("RGBA", (width, height), (255, 255, 255, 255))

    for y in range(height):
        for x in range(width):
            if horizontal:
                intensity = int((x / width) * 255)
            else:
                intensity = int((y / height) * 255)
            img.putpixel((x, y), (intensity, intensity, intensity, 255))

    path = os.path.join(FIXTURES_DIR, f"{name}.png")
    img.save(path)
    print(f"Created: {path}")
    return path

def create_checkerboard(name, size, cell_size):
    """Create a checkerboard pattern."""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    for y in range(0, size, cell_size):
        for x in range(0, size, cell_size):
            if ((x // cell_size) + (y // cell_size)) % 2 == 0:
                draw.rectangle([x, y, x + cell_size - 1, y + cell_size - 1], fill=(0, 0, 0, 255))

    path = os.path.join(FIXTURES_DIR, f"{name}.png")
    img.save(path)
    print(f"Created: {path}")
    return path

def create_unique_pattern(name, size):
    """Create a unique pattern that won't match anything else."""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    # Draw unique diagonal pattern
    for i in range(0, size, 4):
        draw.line([(i, 0), (0, i)], fill=(255, 0, 0, 255), width=1)
        draw.line([(size-1, i), (size-1-i, size-1)], fill=(0, 0, 255, 255), width=1)

    # Center marker
    center = size // 2
    draw.ellipse([center-5, center-5, center+5, center+5], fill=(0, 255, 0, 255))

    path = os.path.join(FIXTURES_DIR, f"{name}.png")
    img.save(path)
    print(f"Created: {path}")
    return path

def main():
    print("=== Generating Zikuli Test Fixtures ===\n")
    ensure_dir()

    # Solid color squares (for basic template matching)
    print("Creating solid squares...")
    create_solid_square("red_square_30x30", 30, (255, 0, 0))
    create_solid_square("red_square_50x50", 50, (255, 0, 0))
    create_solid_square("blue_square_30x30", 30, (0, 0, 255))
    create_solid_square("blue_square_50x50", 50, (0, 0, 255))
    create_solid_square("green_square_30x30", 30, (0, 255, 0))
    create_solid_square("white_square_30x30", 30, (255, 255, 255))
    create_solid_square("black_square_30x30", 30, (0, 0, 0))

    # Minimum size (12x12 is MIN_TARGET_DIMENSION)
    create_solid_square("red_square_12x12", 12, (255, 0, 0))
    create_solid_square("red_square_15x15", 15, (255, 0, 0))

    print("\nCreating buttons...")
    create_button("button_ok", 60, 25, (200, 200, 200), (100, 100, 100), "OK")
    create_button("button_cancel", 60, 25, (200, 200, 200), (100, 100, 100), "Cancel")
    create_button("button_plain", 50, 25, (180, 180, 180), (80, 80, 80))

    print("\nCreating crosshairs...")
    create_crosshair("crosshair_red_30", 30, (255, 0, 0))
    create_crosshair("crosshair_black_50", 50, (0, 0, 0))

    print("\nCreating gradients...")
    create_gradient("gradient_h_100x30", 100, 30, horizontal=True)
    create_gradient("gradient_v_30x100", 30, 100, horizontal=False)

    print("\nCreating patterns...")
    create_checkerboard("checker_60x60_10", 60, 10)
    create_unique_pattern("unique_40x40", 40)

    print("\n=== Done! ===")
    print(f"Fixtures created in: {FIXTURES_DIR}")

if __name__ == "__main__":
    main()
