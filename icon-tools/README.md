# nopu iOS App Icon Tools

This folder contains all tools and assets for generating nopu app icons.

## File Structure

```
icon-tools/
├── README.md                 # This documentation
├── nopu_icon.svg            # Icon design file
├── convert_icon.py          # Icon conversion script
├── generate_icons.py        # Complete icon generation script
├── generate.sh              # One-click generation script
└── generated-icons/         # Generated PNG icon files folder
```

## Quick Start

### Install Dependencies

```bash
pip3 install cairosvg pillow --break-system-packages
```

### Generate Icons

**Method 1: Simple generation**
```bash
python3 convert_icon.py
```

**Method 2: One-click script**
```bash
./generate.sh
```

**Method 3: Complete generation**
```bash
python3 generate_icons.py nopu_icon.svg generated-icons
```

### Integrate into Xcode Project

```bash
# Copy main icon to Xcode project
cp generated-icons/nopu_icon_1024.png ../nopu/Assets.xcassets/AppIcon.appiconset/
```

## Generated Icon Sizes

| Size | Purpose | Scale |
|------|---------|-------|
| 1024×1024 | App Store | 1x |
| 180×180 | iPhone App Icon | 3x |
| 120×120 | iPhone App Icon | 2x |
| 87×87 | iPhone Settings | 3x |
| 80×80 | iPhone/iPad Spotlight | 2x |
| 58×58 | iPhone Settings | 2x |
| 40×40 | iPhone/iPad Spotlight | 1x |
| 29×29 | iPhone Settings | 1x |
| 256×256 | Preview | - |