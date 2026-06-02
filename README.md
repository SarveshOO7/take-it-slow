# Take It Slow — YouTube Blocker for iOS

A Flutter iOS app that enforces a **10-minute cool-down** every time you try to open YouTube, then grants you a configurable access window (default 60 minutes) before blocking it again.

```
Open YouTube → blocked immediately → 10-min wait → access window → blocked again
```

---

## How it works

| Phase | What happens |
|-------|--------------|
| **Blocked (idle)** | YouTube is blocked via iOS Screen Time. Any attempt to open it shows the restriction screen. |
| **Countdown** | The DeviceActivityMonitor extension detects the YouTube open, blocks it harder, and notifies you to open Take It Slow. A 10-minute countdown ticks. |
| **Accessible** | After 10 min, the app removes the Screen Time block. YouTube is usable. |
| **Auto re-block** | When the access window expires (default 60 min, configurable to any value 5–480 min), a background task re-applies the block and the cycle resets. |

---

## Quick start

```bash
# 1. Clone & bootstrap
git clone https://github.com/sarveshoo7/take-it-slow
cd take-it-slow
chmod +x setup.sh && ./setup.sh

# 2. Follow the printed Xcode instructions (5 minutes)

# 3. Build on a real device
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
# Product → Run (⌘R)
```

> **Screen Time APIs don't work in the simulator.** You must run on a physical iPhone or iPad.

---

## Requirements

- Flutter ≥ 3.3
- Xcode 15+, iOS 16+
- Apple Developer account (paid — Family Controls capability requires it)
- Real iOS device for testing

---

## Architecture

```
lib/
├── main.dart                         Entry point
├── models/app_timer_state.dart       BlockerPhase enum
├── services/blocker_service.dart     Timer logic + MethodChannel bridge
├── screens/
│   ├── home_screen.dart              Animated phase-switching UI
│   └── settings_screen.dart         Configurable access duration
└── widgets/countdown_ring.dart       Custom arc progress ring

ios/
├── Runner/
│   ├── AppDelegate.swift             BGTaskScheduler setup
│   ├── YouTubeBlockerService.swift   FamilyControls + ManagedSettings
│   ├── FamilyActivityPickerView.swift SwiftUI app-picker sheet
│   └── Runner.entitlements           FamilyControls + AppGroup + BGTask
└── DeviceActivityMonitorExtension/
    ├── DeviceActivityMonitorExtension.swift  Detects YouTube usage, blocks
    ├── Info.plist
    └── DeviceActivityMonitorExtension.entitlements
```

### MethodChannel API (`com.takeitSlow/blocker`)

| Method | Direction | Description |
|--------|-----------|-------------|
| `requestAuthorization` | Flutter → iOS | Prompts FamilyControls authorization |
| `checkAuthorization` | Flutter → iOS | Returns `true` if already approved |
| `blockApps` | Flutter → iOS | Applies ManagedSettings block |
| `unblockApps` | Flutter → iOS | Removes block, schedules BGTask to re-block |
| `showAppPicker` | Flutter → iOS | Presents FamilyActivityPicker sheet |
| `youtubeDetected` | iOS → Flutter | Extension detected first YouTube use |

---

## Xcode setup (detailed)

### 1. Bundle IDs
- **Runner**: `com.takeitSlow.takeItSlow`
- **Extension**: `com.takeitSlow.takeItSlow.DeviceActivityMonitorExtension`

### 2. Capabilities on Runner target
- **Family Controls** ← most important; requires paid dev account
- **App Groups** → `group.com.takeitSlow`
- **Background Modes** → Background fetch + Background processing

### 3. Info.plist keys (Runner)
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.takeitSlow.reblock</string>
</array>
```

### 4. Extension target
- File → New → Target → **DeviceActivity Monitor Extension**
- Product name: `DeviceActivityMonitorExtension`
- Add capability: App Groups → `group.com.takeitSlow`
- Replace generated Swift file with `ios/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift`

---

## Configuring the access window

Tap the gear icon → drag the slider or type an exact number of minutes (5–480).
Quick presets: 15 min, 30 min, 1 hr, 2 hrs.

The setting persists across launches and is read by both the Flutter timer and the iOS background task.

---

## FAQ

**Why do I need a paid developer account?**  
Apple's `com.apple.developer.family-controls` entitlement (required for `FamilyControls.framework`) is not available with a free provisioning profile.

**Can I block other apps too?**  
Yes. Tap the gear → "Change App Selection" and pick any apps from the picker. All selected apps share the same wait/access cycle.

**Does it work when the app is closed?**  
Yes. The block is enforced by iOS Screen Time (not by the app process). The access-window countdown is backed by a `BGAppRefreshTask` that fires when the window expires.

**Can I bypass it?**  
Via Settings → Screen Time → [app name] → you could remove the restriction manually. This app is a self-discipline tool, not parental control.
