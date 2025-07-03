#!/bin/bash

# Generate all required app icon sizes from a 1024x1024 source image
# Usage: ./generate-app-icons.sh input.png

if [ $# -eq 0 ]; then
    echo "Usage: $0 <input-1024x1024.png>"
    exit 1
fi

INPUT="$1"
OUTPUT_DIR="AppIcon.appiconset"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate all required sizes
echo "Generating app icons..."

# iPhone Notification 20pt
sips -z 40 40 "$INPUT" --out "$OUTPUT_DIR/Icon-20@2x.png"
sips -z 60 60 "$INPUT" --out "$OUTPUT_DIR/Icon-20@3x.png"

# iPhone Settings 29pt
sips -z 58 58 "$INPUT" --out "$OUTPUT_DIR/Icon-29@2x.png"
sips -z 87 87 "$INPUT" --out "$OUTPUT_DIR/Icon-29@3x.png"

# iPhone Spotlight 40pt
sips -z 80 80 "$INPUT" --out "$OUTPUT_DIR/Icon-40@2x.png"
sips -z 120 120 "$INPUT" --out "$OUTPUT_DIR/Icon-40@3x.png"

# iPhone App 60pt
sips -z 120 120 "$INPUT" --out "$OUTPUT_DIR/Icon-60@2x.png"
sips -z 180 180 "$INPUT" --out "$OUTPUT_DIR/Icon-60@3x.png"

# App Store
cp "$INPUT" "$OUTPUT_DIR/Icon-1024.png"

# Generate Contents.json
cat > "$OUTPUT_DIR/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "Icon-20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ App icons generated in $OUTPUT_DIR/"
echo "Now copy the contents to: Momentum/Momentum/Assets.xcassets/AppIcon.appiconset/"