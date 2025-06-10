#!/usr/bin/env python3
"""
Generate iOS App Icons from SVG
Generates all required icon sizes for iOS apps from the SVG source
"""

import os
import subprocess
from pathlib import Path

# iOS App Icon sizes (points and pixels for @1x, @2x, @3x)
IOS_ICON_SIZES = {
    # App Store
    'AppStore': [(1024, 1024)],
    
    # iPhone
    'iPhone_Settings': [(29, 29), (58, 58), (87, 87)],
    'iPhone_Spotlight': [(40, 40), (80, 80), (120, 120)],
    'iPhone_App': [(60, 60), (120, 120), (180, 180)],
    
    # iPad
    'iPad_Settings': [(29, 29), (58, 58)],
    'iPad_Spotlight': [(40, 40), (80, 80)],
    'iPad_App': [(76, 76), (152, 152), (167, 167)],
    
    # iPad Pro
    'iPad_Pro_App': [(83.5, 167)],
    
    # Notification
    'Notification': [(20, 20), (40, 40), (60, 60)],
}

def generate_icon_set(svg_file, output_dir):
    """Generate complete iOS icon set from SVG file"""
    
    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)
    
    # Create AppIcon.appiconset directory
    appiconset_path = output_path / "AppIcon.appiconset"
    appiconset_path.mkdir(exist_ok=True)
    
    # Generate all icon sizes
    contents_json = {
        "images": [],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    for category, sizes in IOS_ICON_SIZES.items():
        for width, height in sizes:
            # Determine scale and idiom
            if width == height:
                if width <= 29:
                    scale = "1x" if width == 29 else "2x" if width == 58 else "3x"
                    size = "29x29"
                    idiom = "iphone" if category.startswith('iPhone') else "ipad"
                elif width <= 40:
                    scale = "1x" if width == 40 else "2x" if width == 80 else "3x"
                    size = "40x40" 
                    idiom = "iphone" if category.startswith('iPhone') else "ipad"
                elif width <= 60:
                    scale = "1x" if width == 60 else "2x" if width == 120 else "3x"
                    size = "60x60"
                    idiom = "iphone"
                elif width <= 76:
                    scale = "1x" if width == 76 else "2x"
                    size = "76x76"
                    idiom = "ipad"
                elif width == 167:
                    scale = "2x"
                    size = "83.5x83.5"
                    idiom = "ipad"
                elif width == 180:
                    scale = "3x"
                    size = "60x60"
                    idiom = "iphone"
                elif width == 1024:
                    scale = "1x"
                    size = "1024x1024"
                    idiom = "ios-marketing"
                else:
                    continue
                    
                filename = f"icon_{int(width)}x{int(height)}.png"
                
                # Generate PNG using cairosvg
                try:
                    import cairosvg
                    cairosvg.svg2png(
                        url=svg_file,
                        write_to=str(appiconset_path / filename),
                        output_width=int(width),
                        output_height=int(height)
                    )
                    print(f"Generated: {filename}")
                    
                    # Add to Contents.json
                    if width != 1024:  # App Store icon doesn't go in Contents.json for regular app icons
                        contents_json["images"].append({
                            "filename": filename,
                            "idiom": idiom,
                            "scale": scale,
                            "size": size
                        })
                    
                except Exception as e:
                    print(f"Error generating {filename}: {e}")
                    print("Please install cairosvg: pip install cairosvg")
    
    # Write Contents.json
    import json
    with open(appiconset_path / "Contents.json", "w") as f:
        json.dump(contents_json, f, indent=2)
    
    print(f"\nIcon set generated in: {appiconset_path}")
    print("Copy the AppIcon.appiconset folder to your Xcode project's Assets.xcassets")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 3:
        print("Usage: python generate_icons.py <svg_file> <output_directory>")
        sys.exit(1)
    
    svg_file = sys.argv[1]
    output_dir = sys.argv[2]
    
    if not os.path.exists(svg_file):
        print(f"Error: SVG file '{svg_file}' not found")
        sys.exit(1)
    
    generate_icon_set(svg_file, output_dir) 