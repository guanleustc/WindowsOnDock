#!/bin/bash

# Build and package WindowsOnDock app
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="WindowsOnDock"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="$PROJECT_NAME.app"

echo "Building $PROJECT_NAME..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app in Release mode
xcodebuild -project "$SCRIPT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build

# Copy the built app to the build folder
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME"
if [ -d "$APP_PATH" ]; then
    cp -R "$APP_PATH" "$BUILD_DIR/$APP_NAME"

    # Create a zip for distribution
    cd "$BUILD_DIR"
    zip -r "$PROJECT_NAME.zip" "$APP_NAME"

    echo ""
    echo "Build complete!"
    echo "App: $BUILD_DIR/$APP_NAME"
    echo "Zip: $BUILD_DIR/$PROJECT_NAME.zip"
else
    echo "Error: Build failed - app not found at $APP_PATH"
    exit 1
fi
