#!/bin/bash
# Run this ONCE after installing Flutter to generate platform directories.
# This script creates a temp Flutter project and copies platforms into Lunaris.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMP_DIR=$(mktemp -d)

echo "Generating platform scaffolds..."
cd "$TEMP_DIR"
flutter create --org com.lunaris --project-name lunaris --platforms android,ios,linux,macos,windows,web temp_project

echo "Copying platform directories..."
for platform in android ios linux macos windows web; do
  if [ -d "temp_project/$platform" ]; then
    cp -r "temp_project/$platform" "$PROJECT_DIR/"
    echo "  [ok] $platform"
  fi
done

rm -rf "$TEMP_DIR"

echo ""
echo "Done! Now run:"
echo "  cd $PROJECT_DIR"
echo "  flutter pub get"
echo "  dart run build_runner build"
echo "  flutter run -d linux   # (or your preferred platform)"
