#!/usr/bin/env python3

import cairosvg
import os

# Create generated-icons directory
os.makedirs('generated-icons', exist_ok=True)

# Generate 1024x1024 icon for App Store
cairosvg.svg2png(
    url='nopu_icon.svg',
    write_to='generated-icons/nopu_icon_1024.png',
    output_width=1024,
    output_height=1024
)

print('✅ Generated 1024x1024 icon: generated-icons/nopu_icon_1024.png')

# Generate smaller preview
cairosvg.svg2png(
    url='nopu_icon.svg',
    write_to='generated-icons/nopu_icon_256.png',
    output_width=256,
    output_height=256
)

print('✅ Generated 256x256 preview: generated-icons/nopu_icon_256.png')

# Generate standard iOS sizes
sizes = [
    (180, 'iPhone App @3x'),
    (120, 'iPhone App @2x'),
    (87, 'Settings @3x'),
    (80, 'Spotlight @2x'),
    (58, 'Settings @2x'),
    (40, 'Spotlight @1x'),
    (29, 'Settings @1x')
]

for size, desc in sizes:
    cairosvg.svg2png(
        url='nopu_icon.svg',
        write_to=f'generated-icons/nopu_icon_{size}.png',
        output_width=size,
        output_height=size
    )
    print(f'✅ Generated {size}x{size} ({desc}): generated-icons/nopu_icon_{size}.png')

print('\n🎉 All icon sizes generated successfully!')
print('📁 Check the "generated-icons" folder for all generated PNG files')
print('📋 To copy to Xcode project:')
print('   cp generated-icons/nopu_icon_1024.png ../nopu/Assets.xcassets/AppIcon.appiconset/') 