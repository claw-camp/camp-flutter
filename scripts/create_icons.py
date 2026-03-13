#!/usr/bin/env python3
"""
Generate Flutter app icons from the image.
Usage: python3 scripts/create_icons.py <image_path> <output_dir>
"""

import os
import sys

def create_flutter_icons(image_path, output_dir):
    """Create all required icon sizes for Flutter app."""
    try:
        from PIL import Image
    except ImportError:
        print("Pillow not installed. Installing...")
        os.system("pip3 install Pillow")
        from PIL import Image
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Open original image
    img = Image.open(image_path)
    print(f"Original image size: {img.size}")
    
    # Define icon sizes
    icon_sizes = [
        (512, 512),   # iOS App Store
        (192, 192),   # iOS App Store (@2x)
        (144, 144),   # iOS App Store (@3x)
        (96, 96),      # iOS App Store (@2x)
        (72, 72),      # iOS App Store (@3x)
        (48, 48),      # Android Play Store
    ]
    
    for size in icon_sizes:
        # Resize image
        icon = img.resize((size[0], size[1]), Image.LANCZOS)
        
        # Generate filename
        if size == (512, 512):
            filename = "icon-512.png"
        elif size == (192, 192):
            filename = "icon-192.png"
        elif size == (144, 144):
            filename = "icon-144.png"
        elif size == (96, 96):
            filename = "icon-96.png"
        elif size == (72, 72):
            filename = "icon-72.png"
        elif size == (48, 48):
            filename = "icon-48.png"
        
        # Save icon
        output_path_full = os.path.join(output_dir, filename)
        icon.save(output_path_full)
        print(f"Created {filename}")
    
    print("All icons created successfully!")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 create_icons.py <image_path> <output_dir>")
        sys.exit(1)
    
    # Run icon generation
    image_path = sys.argv[1]
    output_dir = sys.argv[2]
    create_flutter_icons(image_path, output_dir)
