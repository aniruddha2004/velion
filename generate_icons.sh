#!/bin/bash

# Generate launcher icons for Android
# This script creates placeholder icons - in production, use flutter_launcher_icons package

cd android/app/src/main/res

# Create colored background
for dir in mipmap-*dpi; do
  case $dir in
    mipmap-mdpi) size=48 ;;
    mipmap-hdpi) size=72 ;;
    mipmap-xhdpi) size=96 ;;
    mipmap-xxhdpi) size=144 ;;
    mipmap-xxxhdpi) size=192 ;;
    *) continue ;;
  esac
  
  # Create simple colored icon using ImageMagick if available
  if command -v convert &> /dev/null; then
    convert -size ${size}x${size} xc:"#6366F1" "$dir/ic_launcher.png"
    echo "Created $dir/ic_launcher.png (${size}x${size})"
  fi
done

echo "Icon generation complete!"
echo "For production icons, run: flutter pub run flutter_launcher_icons:main"
