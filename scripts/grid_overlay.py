#!/usr/bin/env python3
"""
Grid overlay script for Zikuli screenshots.
Adds a labeled coordinate grid to help identify click targets.
"""

import sys
from PIL import Image, ImageDraw, ImageFont

def add_grid_overlay(input_path, output_path=None, grid_size=100):
    """Add a numbered grid overlay to an image."""

    if output_path is None:
        output_path = input_path.replace('.png', '_grid.png')

    # Load image
    img = Image.open(input_path)
    width, height = img.size

    # Add padding for labels
    padding_top = 25
    padding_left = 35
    new_width = width + padding_left
    new_height = height + padding_top

    # Create new image with padding
    new_img = Image.new('RGBA', (new_width, new_height), (40, 40, 40, 255))
    new_img.paste(img, (padding_left, padding_top))

    draw = ImageDraw.Draw(new_img)

    # Try to use a monospace font, fall back to default
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 11)
        font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 9)
    except:
        font = ImageFont.load_default()
        font_small = font

    # Colors
    grid_color = (255, 0, 0, 100)  # Semi-transparent red
    label_color = (255, 255, 0, 255)  # Yellow
    major_grid_color = (255, 100, 100, 150)  # Brighter red for major lines

    # Draw vertical grid lines and X labels
    for x in range(0, width + 1, grid_size):
        screen_x = x + padding_left

        # Major line every 500px
        if x % 500 == 0:
            draw.line([(screen_x, padding_top), (screen_x, new_height)], fill=major_grid_color, width=2)
        else:
            draw.line([(screen_x, padding_top), (screen_x, new_height)], fill=grid_color, width=1)

        # X coordinate label at top
        if x % 200 == 0:
            draw.text((screen_x + 2, 2), str(x), fill=label_color, font=font)

    # Draw horizontal grid lines and Y labels
    for y in range(0, height + 1, grid_size):
        screen_y = y + padding_top

        # Major line every 500px
        if y % 500 == 0:
            draw.line([(padding_left, screen_y), (new_width, screen_y)], fill=major_grid_color, width=2)
        else:
            draw.line([(padding_left, screen_y), (new_width, screen_y)], fill=grid_color, width=1)

        # Y coordinate label on left
        if y % 200 == 0:
            draw.text((2, screen_y + 2), str(y), fill=label_color, font=font)

    # Draw intersection markers every 200px with coordinates
    marker_color = (0, 255, 0, 200)  # Green
    for x in range(0, width + 1, 200):
        for y in range(0, height + 1, 200):
            screen_x = x + padding_left
            screen_y = y + padding_top

            # Draw a small crosshair
            draw.ellipse([screen_x-3, screen_y-3, screen_x+3, screen_y+3], fill=marker_color)

    # Add dimension info at bottom-right
    info_text = f"{width}x{height}"
    draw.rectangle([new_width-80, new_height-20, new_width, new_height], fill=(0, 0, 0, 200))
    draw.text((new_width-75, new_height-18), info_text, fill=(255, 255, 255), font=font)

    # Save
    new_img.save(output_path)
    print(f"Grid overlay saved to: {output_path}")
    print(f"Original size: {width}x{height}")
    print(f"Grid size: {grid_size}px")

    return output_path

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: grid_overlay.py <input.png> [output.png] [grid_size]")
        print("  grid_size defaults to 100px")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    grid_size = int(sys.argv[3]) if len(sys.argv) > 3 else 100

    add_grid_overlay(input_path, output_path, grid_size)
