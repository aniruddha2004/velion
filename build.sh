#!/bin/bash

# Build script for Personal News Assistant

set -e

echo "=========================================="
echo "Building Personal News Assistant"
echo "=========================================="

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Get dependencies
echo "Installing dependencies..."
flutter pub get

# Generate Hive adapters
echo "Generating code..."
dart run build_runner build --delete-conflicting-outputs

# Analyze code
echo "Analyzing code..."
flutter analyze

# Run tests
echo "Running tests..."
flutter test

# Build release APK
echo "Building release APK..."
flutter build apk --release

# Build App Bundle for Play Store
echo "Building App Bundle..."
flutter build appbundle --release

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
echo "AAB location: build/app/outputs/bundle/release/app-release.aab"
echo ""
