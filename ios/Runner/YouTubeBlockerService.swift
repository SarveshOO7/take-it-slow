import Foundation
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity
import BackgroundTasks
import UserNotifications

// Shared UserDefaults suite used by both the main app and the
// DeviceActivityMonitor extension to pass state.
let sharedDefaults = UserDefaults(suiteName: "group.com.takeitSlow")!

@MainActor
final class YouTubeBlockerService: NSObject {

    static let bgTaskId = "com.takeitSlow.reblock"

    private let channel: FlutterMethodChannel
    private let store = ManagedSettingsStore()

    // Persisted across launches via shared UserDefaults.
    private var selection: FamilyActivitySelection {
        get {
            guard let data = sharedDefaults.data(forKey: "app_selection"),
                  let s = try? JSONDecoder().decode(
                      FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return s
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                sharedDefaults.set(data, forKey: "app_selection")
            }
        }
    }

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        requestNotificationPermission()
    }

    // MARK: - Flutter method handler

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization":
            requestAuthorization(result: result)
        case "checkAuthorization":
            result(AuthorizationCenter.shared.authorizationStatus == .approved)
        case "blockApps":
            applyBlock()
            result(nil)
        case "unblockApps":
            removeBlock()
            scheduleReblockTask(after: accessWindowSeconds())
            result(nil)
        case "showAppPicker":
            presentAppPicker(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Authorization

    private func requestAuthorization(result: @escaping FlutterResult) {
        Task {
            do {
                try await AuthorizationCenter.shared
                    .requestAuthorization(for: .individual)
                result(true)
            } catch {
                result(false)
            }
        }
    }

    // MARK: - Blocking

    func applyBlock() {
        let s = selection
        store.application.blockedApplications = s.applicationTokens
        store.webDomain.blockedDomains = s.webDomainTokens
        setupDeviceActivityMonitoring()
    }

    func removeBlock() {
        store.clearAllSettings()
        stopDeviceActivityMonitoring()
    }

    // MARK: - DeviceActivity (detect first YouTube use)

    private func setupDeviceActivityMonitoring() {
        guard !selection.applicationTokens.isEmpty else { return }
        let center = DeviceActivityCenter()
        // Monitor 24 hours/day, every day.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: nil
        )
        // Threshold: 1 second of usage → extension fires immediately.
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            threshold: DateComponents(second: 1)
        )
        try? center.startMonitoring(
            .youtubeWatch,
            during: schedule,
            events: [.youtubeThreshold: event]
        )
    }

    private func stopDeviceActivityMonitoring() {
        DeviceActivityCenter().stopMonitoring([.youtubeWatch])
    }

    // MARK: - App picker (FamilyActivityPicker)

    private func presentAppPicker(result: @escaping FlutterResult) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController
        else {
            result(false)
            return
        }

        var currentSelection = selection
        let picker = FamilyActivityPickerView(
            selection: Binding(
                get: { currentSelection },
                set: { currentSelection = $0 }
            ),
            onDone: { [weak self] in
                self?.selection = currentSelection
                self?.applyBlock()
                root.dismiss(animated: true)
                result(true)
            },
            onCancel: {
                root.dismiss(animated: true)
                result(false)
            }
        )

        let host = UIHostingController(rootView: picker)
        host.modalPresentationStyle = .pageSheet
        root.present(host, animated: true)
    }

    // MARK: - Background task (re-block after access window)

    func scheduleReblockTask(after seconds: TimeInterval) {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: seconds)
        try? BGTaskScheduler.shared.submit(request)
    }

    func handleBackgroundUnblock(_ task: BGAppRefreshTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        applyBlock()
        sendBlockedNotification()
        task.setTaskCompleted(success: true)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    private func sendBlockedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "YouTube is blocked again"
        content.body = "Your access window ended. Open Take It Slow to start a new wait."
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Helpers

    private func accessWindowSeconds() -> TimeInterval {
        let minutes = sharedDefaults.integer(forKey: "access_duration_minutes")
        return TimeInterval((minutes > 0 ? minutes : 60) * 60)
    }
}

// MARK: - DeviceActivity name extensions

extension DeviceActivityName {
    static let youtubeWatch = Self("youtubeWatch")
}

extension DeviceActivityEvent.Name {
    static let youtubeThreshold = Self("youtubeThreshold")
}
