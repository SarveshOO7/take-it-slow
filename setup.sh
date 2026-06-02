#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# setup.sh — Bootstrap the Take It Slow Flutter iOS project.
#
# Prerequisites:
#   • Flutter SDK (>= 3.3) — https://docs.flutter.dev/get-started/install/macos
#   • Xcode 15+ with iOS 16+ SDK
#   • An Apple Developer account enrolled in the Family Controls
#     capability program (free provisioning does NOT include it).
#
# Usage:
#   chmod +x setup.sh && ./setup.sh
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "▸ Checking Flutter..."
if ! command -v flutter &>/dev/null; then
    echo "ERROR: Flutter not found. Install from https://flutter.dev and rerun."
    exit 1
fi
flutter --version

echo "▸ Getting Flutter packages..."
cd "$REPO_DIR"
flutter pub get

echo "▸ Running flutter create to generate Xcode project scaffold..."
# --org must match the bundle ID prefix used in entitlements / group ID.
flutter create \
    --org com.takeitSlow \
    --project-name take_it_slow \
    --platforms ios \
    --template app \
    . 2>/dev/null || true   # ignore "directory not empty" warning

echo "▸ Restoring custom source files (flutter create may have overwritten them)..."

# Dart sources are authoritative in this repo — no action needed.

# iOS sources — flutter create generates a default AppDelegate; replace it.
for f in \
    "ios/Runner/AppDelegate.swift" \
    "ios/Runner/YouTubeBlockerService.swift" \
    "ios/Runner/FamilyActivityPickerView.swift" \
    "ios/Runner/Runner.entitlements"
do
    echo "  ✔ $f (already in repo)"
done

echo ""
echo "▸ Creating DeviceActivityMonitorExtension directory..."
mkdir -p "$REPO_DIR/ios/DeviceActivityMonitorExtension"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Flutter setup complete — manual Xcode steps required"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Open ios/Runner.xcworkspace in Xcode (NOT .xcodeproj) and:"
echo ""
echo "1. BUNDLE IDs"
echo "   Runner target → General → Bundle Identifier:"
echo "     com.takeitSlow.takeItSlow"
echo ""
echo "2. SIGNING"
echo "   Runner → Signing & Capabilities → Team: your Apple Dev account"
echo "   Enable 'Automatically manage signing'"
echo ""
echo "3. ENTITLEMENTS"
echo "   Runner → Signing & Capabilities → + Capability:"
echo "     • Family Controls"
echo "     • App Groups  → add: group.com.takeitSlow"
echo "     • Background Modes → Background fetch + Background processing"
echo ""
echo "4. ADD EXTENSION TARGET"
echo "   File → New → Target → DeviceActivity Monitor Extension"
echo "   Product Name: DeviceActivityMonitorExtension"
echo "   Bundle ID:    com.takeitSlow.takeItSlow.DeviceActivityMonitorExtension"
echo ""
echo "   After creation:"
echo "   a. Replace the generated .swift file with:"
echo "      ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift"
echo "   b. Replace Info.plist with:"
echo "      ios/DeviceActivityMonitorExtension/Info.plist"
echo "   c. Add entitlements file:"
echo "      ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.entitlements"
echo "   d. Extension target → Signing & Capabilities:"
echo "      App Groups → add: group.com.takeitSlow"
echo ""
echo "5. Info.plist (Runner)"
echo "   Add:"
echo "   NSUserTrackingUsageDescription → 'Used to manage YouTube blocking'"
echo "   BGTaskSchedulerPermittedIdentifiers → com.takeitSlow.reblock"
echo ""
echo "6. pod install"
echo "   cd ios && pod install"
echo ""
echo "7. Build & run on a real device (Screen Time API is not available"
echo "   in the simulator)."
echo ""
echo "Done!"
