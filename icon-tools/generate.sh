#!/bin/bash

# nopu icon generation and deployment script
echo "🎨 nopu Icon Generation Tool"
echo "==========================="

# Check if running in correct directory
if [ ! -f "nopu_icon.svg" ]; then
    echo "❌ Error: Please run this script in the icon-tools directory"
    exit 1
fi

# Check Python dependencies
echo "🔍 Checking environment dependencies..."
if ! python3 -c "import cairosvg" 2>/dev/null; then
    echo "📦 Installing cairosvg..."
    pip3 install cairosvg pillow --break-system-packages
fi

# Generate icons
echo "🖼️  Generating icons..."
python3 convert_icon.py

# Check if generation succeeded
if [ ! -f "generated-icons/nopu_icon_1024.png" ]; then
    echo "❌ Icon generation failed"
    exit 1
fi

# Copy to Xcode project
echo "📱 Copying icon to Xcode project..."
if [ -d "../nopu/Assets.xcassets/AppIcon.appiconset/" ]; then
    cp generated-icons/nopu_icon_1024.png ../nopu/Assets.xcassets/AppIcon.appiconset/
    echo "✅ Icon copied to Xcode project"
else
    echo "⚠️  Warning: Could not find Xcode project directory"
    echo "   Please manually copy: generated-icons/nopu_icon_1024.png"
fi

# Show generation results
echo ""
echo "🎉 Icon generation completed!"
echo "📁 Generated files:"
ls -la generated-icons/
echo ""
echo "💡 Usage tips:"
echo "   • Main icon: generated-icons/nopu_icon_1024.png"
echo "   • Preview icon: generated-icons/nopu_icon_256.png"
echo "   • Other sizes in generated-icons/ folder"
echo ""
echo "🔄 To regenerate: ./generate.sh" 